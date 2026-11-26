import Testing
import Foundation
import HorionKit
@testable import Horion

/// design/mockup-v20 round 1: the event panel by keyboard (Flat Tab, menus by arrows, Option + letter).
@MainActor
@Suite("Panel keyboard")
struct PanelKeyboardTests {
    let r = KeyRouter()
    func key(_ m: AppModel, _ c: String, _ code: UInt16, shift: Bool = false, option: Bool = false, typing: Bool = false) -> Bool {
        r.handle(KeyInput(characters: c, keyCode: code, option: option, shift: shift), typing: typing, window: nil, model: m)
    }
    func tab(_ m: AppModel, shift: Bool = false, typing: Bool = false) -> Bool { key(m, "\t", ShortcutResolver.keyTab, shift: shift, typing: typing) }
    func open(_ m: AppModel) -> CalendarEvent {
        let e = m.layout.timed.flatMap { $0 }.map(\.event).first { m.editorCanEdit($0) && !$0.isAllDay }!
        m.select(eventID: e.id)
        return e
    }

    @Test func tabGoesThroughEveryStopAndWraps() {
        let m = makeModelV4()
        _ = open(m)
        let stops = m.panelStops
        #expect(stops.first == .title && stops.contains(.allDay) && stops.contains(.calendar) && stops.contains(.busy))
        m.focusPanelStop(.title)
        var seen: [PanelStop] = [.title]
        for _ in 1..<stops.count {
            #expect(tab(m, typing: m.panelMenus.stop?.isText == true))
            seen.append(m.panelMenus.stop!)
        }
        #expect(seen == stops)
        #expect(tab(m, typing: m.panelMenus.stop?.isText == true))
        #expect(m.panelMenus.stop == .title && m.panelMenus.focusRequest == .title, "Tab past the last stop wraps to the title")
        #expect(tab(m, shift: true, typing: true))
        #expect(m.panelMenus.stop == stops.last)
    }

    @Test func spaceFlipsAllDayAndEscLeavesTheStop() {
        let m = makeModelV4()
        let e = open(m)
        m.focusPanelStop(.allDay)
        #expect(key(m, " ", 49))
        #expect(m.selectedEvent?.isAllDay == !e.isAllDay)
        #expect(key(m, "\u{1b}", ShortcutResolver.keyEscape))
        #expect(m.panelMenus.stop == nil && m.selectedEventID == e.id, "the first Esc only takes the ring off")
    }

    @Test func menusOpenAndPickByKeyboard() throws {
        let m = makeModelV4()
        let e = open(m)
        m.focusPanelStop(.busy)
        #expect(key(m, "\r", ShortcutResolver.keyReturn))
        #expect(m.panelMenus.open == .availability && m.panelMenus.highlight == "menu:avail:\(e.availability.rawValue)")
        #expect(key(m, "", ShortcutResolver.keyDown))
        #expect(key(m, "\r", ShortcutResolver.keyReturn))
        #expect(m.panelMenus.open == nil && m.selectedEvent?.availability != e.availability && m.panelMenus.stop == .busy)

        let cals = m.store.accounts.flatMap(\.calendars).filter(\.isWritable)
        try #require(cals.count > 1)
        m.focusPanelStop(.calendar)
        #expect(key(m, "", ShortcutResolver.keyDown))
        #expect(m.panelMenus.open == .calendar && m.panelMenus.highlight == "menu:cal:\(e.calendarID)")
        #expect(key(m, "", ShortcutResolver.keyDown))
        #expect(key(m, " ", 49))
        #expect(m.selectedEvent?.calendarID != e.calendarID && m.panelMenus.open == nil)

        // Esc closes a menu and keeps the stop; Tab closes it and moves on
        m.focusPanelStop(.visibility)
        #expect(key(m, " ", 49) && m.panelMenus.open == .visibility)
        #expect(key(m, "\u{1b}", ShortcutResolver.keyEscape))
        #expect(m.panelMenus.open == nil && m.panelMenus.stop == .visibility)
        #expect(key(m, " ", 49) && tab(m))
        #expect(m.panelMenus.open == nil && m.panelMenus.stop != .visibility)
    }

    @Test func remindersByKeyboard() {
        let m = makeModelV4()
        _ = open(m)
        m.focusPanelStop(.addReminder)
        #expect(key(m, "\r", ShortcutResolver.keyReturn) && m.panelMenus.open == .reminders)
        m.panelMenus.highlight = "menu:rem60"
        #expect(key(m, "\r", ShortcutResolver.keyReturn))
        #expect(m.selectedEvent?.reminders.contains(60) == true && m.panelMenus.open == .reminders, "the reminder menu stays open")
        #expect(key(m, "\u{1b}", ShortcutResolver.keyEscape))
        m.focusPanelStop(.reminder(60))
        #expect(key(m, "\u{7f}", ShortcutResolver.keyDelete))
        #expect(m.selectedEvent?.reminders.contains(60) == false && m.selectedEventID != nil, "Delete removes the reminder, not the event")
    }

    @Test func optionLetterJumpsOutsideTextFieldsOnly() {
        let m = makeModelV4()
        _ = open(m)
        #expect(key(m, "k", 40, option: true))
        #expect(m.panelMenus.stop == .calendar && m.panelMenus.open == .calendar)
        m.closePanelMenu()
        #expect(key(m, "l", 37, option: true))
        #expect(m.panelMenus.stop == .place && m.panelMenus.focusRequest == .place)
        // in a field Option types (@ is Option-L on a German keyboard)
        m.panelFieldFocusChanged(.guest)
        #expect(!key(m, "l", 37, option: true, typing: true))
        #expect(m.panelMenus.stop == .guest)
    }

    @Test func otherFocusLeavesTheKeysAlone() {
        let m = makeModelV4()
        _ = open(m)
        // no stop: Tab still selects the next event
        let before = m.selectedEventID
        #expect(tab(m))
        #expect(m.selectedEventID != before && m.panelMenus.stop == nil)
        // the search field has the keyboard
        m.focusPanelStop(.title)
        m.chromeState.searchFocused = true
        #expect(!tab(m, typing: true))
    }
}
