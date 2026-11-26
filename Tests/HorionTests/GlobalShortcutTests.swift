import Testing
import Foundation
import AppKit
@testable import Horion

@Suite("Global shortcuts")
struct GlobalShortcutTests {
    @Test func defaultsAreControlCommandEAndR() {
        let s = AppSettings()
        #expect(s.menuShortcut.display == "\u{2303}\u{2318}E")
        #expect(s.appShortcut.display == "\u{2303}\u{2318}R")
        #expect(s.menuShortcut.on && s.appShortcut.on)
        #expect(!s.menuShortcut.sameKeys(s.appShortcut))
    }

    @Test func olderSettingsGetTheDefaultsAndChangesRoundTrip() throws {
        let old = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"showWeekNumbers":true}"#.utf8))
        #expect(old.menuShortcut == .menuDefault && old.appShortcut == .appDefault)
        // earlier defaults move to the new ones, a switched-off key stays off
        var first = AppSettings()
        first.menuShortcut = GlobalShortcut.oldMenuDefaults[0]
        first.appShortcut = GlobalShortcut.oldAppDefaults[0]
        first.appShortcut.on = false
        let moved = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(first))
        #expect(moved.menuShortcut == .menuDefault)
        #expect(moved.appShortcut.sameKeys(.appDefault) && !moved.appShortcut.on)
        // only a key's own earlier defaults move, and never onto the other key
        let swapped = GlobalShortcut.migrate(menu: GlobalShortcut.oldAppDefaults[0], app: .menuDefault)
        #expect(swapped.menu == GlobalShortcut.oldAppDefaults[0] && swapped.app == .menuDefault)
        let clash = GlobalShortcut.migrate(menu: GlobalShortcut.oldMenuDefaults[1], app: .menuDefault)
        #expect(clash.menu == GlobalShortcut.oldMenuDefaults[1] && clash.app == .menuDefault)
        var s = AppSettings()
        s.appShortcut.on = false
        s.menuShortcut = GlobalShortcut(keyCode: 49, modifiers: GlobalShortcut.mask.rawValue, key: "Space")
        let back = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(s))
        #expect(back == s)
        #expect(back.menuShortcut.display == "\u{2303}\u{2325}\u{21E7}\u{2318}Space")
    }

    @Test func specialKeysGetMenuKeyEquivalents() {
        #expect(GlobalShortcut(keyCode: 49, modifiers: 0, key: "Space").keyEquivalent == " ")
        func fn(_ c: Int) -> String { String(Character(UnicodeScalar(UInt16(c))!)) }
        #expect(GlobalShortcut(keyCode: 96, modifiers: 0, key: "F5").keyEquivalent == fn(NSF5FunctionKey))
        #expect(GlobalShortcut(keyCode: 123, modifiers: 0, key: "\u{2190}").keyEquivalent == fn(NSLeftArrowFunctionKey))
        #expect(GlobalShortcut(keyCode: 117, modifiers: 0, key: "\u{2326}").keyEquivalent == fn(NSDeleteFunctionKey))
        #expect(GlobalShortcut(keyCode: 36, modifiers: 0, key: "\u{21A9}").keyEquivalent == "\r")
        #expect(GlobalShortcut(keyCode: 48, modifiers: 0, key: "\u{21E5}").keyEquivalent == "\t")
        #expect(GlobalShortcut(keyCode: 51, modifiers: 0, key: "\u{232B}").keyEquivalent == "\u{8}")
    }
}
