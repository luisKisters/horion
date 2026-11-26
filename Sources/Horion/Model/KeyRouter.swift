import AppKit
import HorionKit

/// One local key monitor for the whole app. It resolves single-key shortcuts only when no text field is focused
/// (`ShortcutResolver`), drives the command menu (arrows, Backspace out of a mode) while it is open, and keeps keys
/// away from the grid while a sheet is up.
@MainActor
final class KeyRouter {
    static let shared = KeyRouter()
    private var monitor: Any?
    private var flagsMonitor: Any?
    private var mouseMonitor: Any?
    private weak var model: AppModel?

    func install(model: AppModel) {
        self.model = model
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let model = self.model else { return event }
            return MainActor.assumeIsolated { self.handle(event, model: model) ? nil : event }
        }
        // Option alone, held outside a text field: the panel shows its jump letters.
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self, let model = self.model else { return event }
            MainActor.assumeIsolated {
                let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
                let show = mods == .option && model.panelTakesKeys && !self.textFocused(in: event.window ?? NSApp.keyWindow)
                if model.panelMenus.jumpLetters != show { model.panelMenus.jumpLetters = show }
            }
            return event
        }
        // A click takes the keyboard's ring off a switch, button or menu of the panel (a field keeps its own focus).
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let model = self?.model else { return event }
            MainActor.assumeIsolated {
                if let s = model.panelMenus.stop, !s.isText { model.panelMenus.stop = nil }
            }
            return event
        }
    }

    func textFocused(in window: NSWindow?) -> Bool {
        guard let r = window?.firstResponder else { return false }
        return r is NSText || (r as? NSView)?.isKind(of: NSTextView.self) == true
    }

    func handle(_ event: NSEvent, model: AppModel) -> Bool {
        if event.window is NSPanel { return false }
        let mods = event.modifierFlags
        let input = KeyInput(characters: event.charactersIgnoringModifiers ?? "", keyCode: event.keyCode,
                             command: mods.contains(.command), option: mods.contains(.option),
                             control: mods.contains(.control), shift: mods.contains(.shift))
        let window = event.window ?? NSApp.keyWindow
        return handle(input, typing: textFocused(in: window), window: window, model: model)
    }

    /// The routing itself, from a key press already read off the event: `typing` says a text field has the keyboard, `window`
    /// is the one it went to (unit tests drive this without an application object).
    func handle(_ input: KeyInput, typing: Bool, window: NSWindow?, model: AppModel) -> Bool {
        if model.overlay == .command, !input.command {
            switch input.keyCode {
            case ShortcutResolver.keyDown: model.movePaletteSelection(1); return true
            case ShortcutResolver.keyUp: model.movePaletteSelection(-1); return true
            case ShortcutResolver.keyDelete: if model.paletteBack() { return true }
            case 48: return true      // Tab stays in the field
            default:
                if input.control && input.characters == "n" { model.movePaletteSelection(1); return true }
                if input.control && input.characters == "p" { model.movePaletteSelection(-1); return true }
            }
        }

        // ⌘↩ sends the held update, or saves (and invites) the event being created.
        if input.command && !input.option && !input.control && input.keyCode == ShortcutResolver.keyReturn && model.overlay == nil && model.sendShortcut() { return true }

        // The recurring-delete and recurring-edit dialogs: ←/→ or A/D move between the buttons, Tab and ⇧Tab too (wrapping),
        // Return takes the focused one (the safe "This event" until moved).
        let spanDialog: (id: String, choose: (String, SpanChoice) -> Void)? = switch model.overlay {
        case .deleteRecurring(let id)?: (id, model.chooseDelete)
        case .editRecurring(let id)?: (id, model.chooseEdit)
        default: nil
        }
        if let (id, choose) = spanDialog, !input.command, !input.control, !input.option {
            let ch = input.characters.lowercased()
            switch input.keyCode {
            case ShortcutResolver.keyReturn, ShortcutResolver.keyEnter: choose(id, model.spanChoice); return true
            case ShortcutResolver.keyTab: model.moveSpanChoice(id, by: input.shift ? -1 : 1, wrap: true); return true
            case ShortcutResolver.keyLeft: model.moveSpanChoice(id, by: -1, wrap: false); return true
            case ShortcutResolver.keyRight: model.moveSpanChoice(id, by: 1, wrap: false); return true
            default:
                if !input.shift && ch == "a" { model.moveSpanChoice(id, by: -1, wrap: false); return true }
                if !input.shift && ch == "d" { model.moveSpanChoice(id, by: 1, wrap: false); return true }
            }
        }

        // The event panel: Tab through its stops, keys on a switch, button or menu, Option + letter jumps (`handlePanelKey`).
        if model.handlePanelKey(input, typing: typing) { return true }

        guard let action = ShortcutResolver.resolve(input, textFocused: typing) else {
            // A sheet keeps every other key from the grid underneath. Outside a field a bare character has no other
            // meaning: swallow it rather than let it beep.
            return (isSheet(model.overlay) || Self.isBareCharacter(input)) && !typing
        }
        switch model.overlay {
        case .command?:
            if action == .escape || action == .commandMenu || action == .settings { break }
            return typing ? false : true
        case .shortcuts?:
            if action == .showShortcuts || action == .editTitle { model.overlay = nil; return true }
            if action != .escape && action != .commandMenu && action != .settings { return true }
        case .settings?:
            if action == .settings { model.overlay = nil; return true }
            if action != .escape && action != .commandMenu && action != .showShortcuts { return true }
        case .deleteRecurring?, .editRecurring?, .deleteWithGuests?:
            if action != .escape { return true }
        case nil: break
        }
        if action == .escape, typing, model.overlay == nil, let w = window {
            // Esc in a field of the event being created discards it at once; anywhere else the first Esc only leaves
            // the field and the next one peels the layer.
            // Esc in the right column's search field only leaves the field (and clears it next): the draft stays.
            guard model.draftEventID != nil && !model.chromeState.searchFocused else { w.makeFirstResponder(nil); return true }
            model.blurTick += 1
            w.makeFirstResponder(nil)
        }
        return model.handle(action)
    }

    /// One printable character without Command, Control or Option (arrows and function keys arrive as private-use characters).
    static func isBareCharacter(_ k: KeyInput) -> Bool {
        guard !k.command, !k.control, !k.option, k.characters.unicodeScalars.count == 1, let u = k.characters.unicodeScalars.first else { return false }
        return u.value >= 0x20 && u.value != 0x7F && !(0xF700...0xF8FF).contains(u.value)
    }

    private func isSheet(_ o: Overlay?) -> Bool {
        switch o { case .shortcuts?, .settings?, .deleteRecurring?, .editRecurring?, .deleteWithGuests?: true; default: false }
    }
}
