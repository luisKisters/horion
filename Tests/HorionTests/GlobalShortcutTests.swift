import Testing
import Foundation
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
        // the first defaults (⌥⌘C, ⌥⌘H) move to the new ones, a switched-off key stays off
        var first = AppSettings()
        first.menuShortcut = GlobalShortcut.oldDefaults[0]
        first.appShortcut = GlobalShortcut.oldDefaults[1]
        first.appShortcut.on = false
        let moved = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(first))
        #expect(moved.menuShortcut == .menuDefault)
        #expect(moved.appShortcut.sameKeys(.appDefault) && !moved.appShortcut.on)
        var s = AppSettings()
        s.appShortcut.on = false
        s.menuShortcut = GlobalShortcut(keyCode: 49, modifiers: GlobalShortcut.mask.rawValue, key: "Space")
        let back = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(s))
        #expect(back == s)
        #expect(back.menuShortcut.display == "\u{2303}\u{2325}\u{21E7}\u{2318}Space")
    }
}
