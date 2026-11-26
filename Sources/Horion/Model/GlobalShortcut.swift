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
    /// ⌃⌘E opens and closes the menu bar menu.
    static let menuDefault = GlobalShortcut(keyCode: UInt16(kVK_ANSI_E), modifiers: NSEvent.ModifierFlags([.control, .command]).rawValue, key: "E")
    /// ⌃⌘R shows or hides the Horion window.
    static let appDefault = GlobalShortcut(keyCode: UInt16(kVK_ANSI_R), modifiers: NSEvent.ModifierFlags([.control, .command]).rawValue, key: "R")
    /// Earlier defaults of each key (⌥⌘C / ⌥⌘H, then ⌃⌥E / ⌃⌥R): saved settings that still have one get the new default.
    static let oldMenuDefaults = [old(kVK_ANSI_C, [.option, .command], "C"), old(kVK_ANSI_E, [.control, .option], "E")]
    static let oldAppDefaults = [old(kVK_ANSI_H, [.option, .command], "H"), old(kVK_ANSI_R, [.control, .option], "R")]
    private static func old(_ code: Int, _ mods: NSEvent.ModifierFlags, _ key: String) -> GlobalShortcut {
        GlobalShortcut(keyCode: UInt16(code), modifiers: mods.rawValue, key: key)
    }

    /// This shortcut, or `new` (keeping on/off) when it is one of `old`.
    func replacing(_ old: [GlobalShortcut], with new: GlobalShortcut) -> GlobalShortcut {
        guard old.contains(where: sameKeys) else { return self }
        var s = new; s.on = on; return s
    }

    /// The saved menu and app keys with earlier defaults moved to the new ones; a move that would give both the same
    /// keys is left out.
    static func migrate(menu: GlobalShortcut?, app: GlobalShortcut?) -> (menu: GlobalShortcut, app: GlobalShortcut) {
        var m = menu?.replacing(oldMenuDefaults, with: menuDefault) ?? menuDefault
        var a = app?.replacing(oldAppDefaults, with: appDefault) ?? appDefault
        if m.sameKeys(a), let menu { m = menu }
        if m.sameKeys(a), let app { a = app }
        return (m, a)
    }

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

    /// The menu item key equivalent for this shortcut ("" for a key a menu cannot show).
    var keyEquivalent: String {
        // by key code first: arrows, Return, Tab and Delete are recorded with one-glyph names ("←")
        if let c = Self.functionKeys[Int(keyCode)] { return String(Character(UnicodeScalar(UInt16(c))!)) }
        if let s = [kVK_Space: " ", kVK_Return: "\r", kVK_Tab: "\t", kVK_Delete: "\u{8}"][Int(keyCode)] { return s }
        return key.count == 1 ? Self.character(for: keyCode) ?? key.lowercased() : ""
    }

    /// What the key types in the current keyboard layout: the hot key goes by key code, so the menu item that takes the
    /// key while the menu is open must too, also after a layout change.
    private static func character(for keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let layout = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        var dead: UInt32 = 0, length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = layout.withUnsafeBytes { raw in
            UCKeyTranslate(raw.bindMemory(to: UCKeyboardLayout.self).baseAddress!, keyCode, UInt16(kUCKeyActionDisplay), 0,
                           UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, chars.count, &length, &chars)
        }
        guard status == noErr, length > 0 else { return nil }
        let c = String(utf16CodeUnits: chars, count: length).lowercased()
        return c.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) } ? c : nil
    }

    private static let functionKeys: [Int: Int] = [
        kVK_LeftArrow: NSLeftArrowFunctionKey, kVK_RightArrow: NSRightArrowFunctionKey, kVK_UpArrow: NSUpArrowFunctionKey,
        kVK_DownArrow: NSDownArrowFunctionKey, kVK_ForwardDelete: NSDeleteFunctionKey, kVK_Home: NSHomeFunctionKey,
        kVK_End: NSEndFunctionKey, kVK_PageUp: NSPageUpFunctionKey, kVK_PageDown: NSPageDownFunctionKey,
        kVK_F1: NSF1FunctionKey, kVK_F2: NSF2FunctionKey, kVK_F3: NSF3FunctionKey, kVK_F4: NSF4FunctionKey,
        kVK_F5: NSF5FunctionKey, kVK_F6: NSF6FunctionKey, kVK_F7: NSF7FunctionKey, kVK_F8: NSF8FunctionKey,
        kVK_F9: NSF9FunctionKey, kVK_F10: NSF10FunctionKey, kVK_F11: NSF11FunctionKey, kVK_F12: NSF12FunctionKey,
    ]

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
