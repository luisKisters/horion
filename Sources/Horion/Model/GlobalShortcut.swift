import AppKit
import Carbon.HIToolbox

/// A system-wide shortcut the user can record in Settings → Shortcuts: a key plus at least one of ⌃ ⌥ ⌘ (⇧ may join them).
struct GlobalShortcut: Codable, Equatable {
    var keyCode: UInt16
    /// `NSEvent.ModifierFlags` raw value, only ⌃ ⌥ ⇧ ⌘.
    var modifiers: UInt
    /// The key as shown on its cap: "C", "Space", "F5".
    var key: String
    var on = true

    static let mask: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
    /// ⌥⌘C opens and closes the menu bar menu.
    static let menuDefault = GlobalShortcut(keyCode: UInt16(kVK_ANSI_C), modifiers: NSEvent.ModifierFlags([.option, .command]).rawValue, key: "C")
    /// ⌥⌘H shows or hides the Horion window.
    static let appDefault = GlobalShortcut(keyCode: UInt16(kVK_ANSI_H), modifiers: NSEvent.ModifierFlags([.option, .command]).rawValue, key: "H")

    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers).intersection(Self.mask) }

    /// "⌥⌘C", modifiers in the system order.
    var display: String {
        let f = flags
        return (f.contains(.control) ? "\u{2303}" : "") + (f.contains(.option) ? "\u{2325}" : "")
            + (f.contains(.shift) ? "\u{21E7}" : "") + (f.contains(.command) ? "\u{2318}" : "") + key
    }

    var carbonModifiers: UInt32 {
        let f = flags
        var m = 0
        if f.contains(.command) { m |= cmdKey }
        if f.contains(.option) { m |= optionKey }
        if f.contains(.control) { m |= controlKey }
        if f.contains(.shift) { m |= shiftKey }
        return UInt32(m)
    }

    /// The menu item key equivalent that shows this shortcut, when the key is a plain character.
    var keyEquivalent: String { key.count == 1 ? key.lowercased() : "" }

    func matches(_ e: NSEvent) -> Bool { on && e.keyCode == keyCode && e.modifierFlags.intersection(Self.mask) == flags }

    func sameKeys(_ o: GlobalShortcut) -> Bool { keyCode == o.keyCode && flags == o.flags }

    /// The shortcut a key press records, or nil when it has no ⌃ ⌥ ⌘ (a bare key or ⇧ alone would fire while typing).
    init?(_ e: NSEvent) {
        let f = e.modifierFlags.intersection(Self.mask)
        guard !f.intersection([.control, .option, .command]).isEmpty, let key = Self.name(e) else { return nil }
        self.init(keyCode: e.keyCode, modifiers: f.rawValue, key: key)
    }

    init(keyCode: UInt16, modifiers: UInt, key: String, on: Bool = true) {
        self.keyCode = keyCode; self.modifiers = modifiers; self.key = key; self.on = on
    }

    private static let special: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "\u{21A9}", kVK_Tab: "\u{21E5}", kVK_Delete: "\u{232B}", kVK_ForwardDelete: "\u{2326}",
        kVK_LeftArrow: "\u{2190}", kVK_RightArrow: "\u{2192}", kVK_UpArrow: "\u{2191}", kVK_DownArrow: "\u{2193}",
        kVK_Home: "\u{2196}", kVK_End: "\u{2198}", kVK_PageUp: "\u{21DE}", kVK_PageDown: "\u{21DF}",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    private static func name(_ e: NSEvent) -> String? {
        if e.keyCode == UInt16(kVK_Escape) { return nil }
        if let s = special[Int(e.keyCode)] { return s }
        guard let c = e.charactersIgnoringModifiers?.uppercased(), c.count == 1, c.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) })
        else { return nil }
        return c
    }
}
