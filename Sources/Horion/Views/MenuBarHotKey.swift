import AppKit
import Carbon.HIToolbox

/// The two system-wide shortcuts from Settings → Shortcuts: the menu key (⌥⌘C) opens or closes the menu bar menu,
/// the app key (⌥⌘H) shows or hides the window. Carbon hot keys need no Accessibility permission.
/// Registered by the app delegate only, so headless runs never get them.
@MainActor
enum MenuBarHotKey {
    enum Action: UInt32 { case menu = 1, app = 2 }

    private static var keys: [EventHotKeyRef] = []
    private static var handler: EventHandlerRef?
    private static var settings: AppSettings?
    /// While a recorder in Settings listens, the shortcuts are off so the keys reach it.
    private static var suspended = false
    private static var lastFire: [Action: Date] = [:]

    static func register(_ s: AppSettings) {
        guard handler == nil else { return update(s) }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, ev, _ in
            var id = EventHotKeyID()
            GetEventParameter(ev, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &id)
            let n = id.id
            DispatchQueue.main.async { MainActor.assumeIsolated { if let a = MenuBarHotKey.Action(rawValue: n) { MenuBarHotKey.fire(a) } } }
            return noErr
        }, 1, &spec, nil, &handler)
        update(s)
    }

    /// Re-registers after a change in Settings. Does nothing before `register` (headless runs).
    static func update(_ s: AppSettings) {
        guard handler != nil else { return }
        settings = s
        apply()
    }

    static func suspend() { suspended = true; apply() }
    static func resume() { suspended = false; apply() }

    private static func apply() {
        for k in keys { UnregisterEventHotKey(k) }
        keys = []
        guard !suspended, let s = settings else { return }
        for (a, sc) in [(Action.menu, s.menuShortcut), (.app, s.appShortcut)] where sc.on {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: OSType(0x434C_4452), id: a.rawValue)   // "CLDR"
            if RegisterEventHotKey(UInt32(sc.keyCode), sc.carbonModifiers, id, GetApplicationEventTarget(), 0, &ref) == noErr, let ref {
                keys.append(ref)
            }
        }
    }

    /// Runs a shortcut. The open menu sees the key press too (its key monitor), so a second call within 0.4 s is the same press.
    static func fire(_ a: Action) {
        if let t = lastFire[a], Date().timeIntervalSince(t) < 0.4 { return }
        lastFire[a] = Date()
        switch a {
        case .menu: MenuBarControl.toggle()
        case .app: MainWindow.toggle()
        }
    }

    static func unregister() {
        for k in keys { UnregisterEventHotKey(k) }
        keys = []
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }
}
