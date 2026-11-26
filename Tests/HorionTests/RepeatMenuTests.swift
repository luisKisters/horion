import Testing
import Foundation
import HorionKit
@testable import Horion

/// The editor's Repeat row: a menu that changes the whole series (design/mockup-v11 FEEDBACK B2).
@MainActor
@Suite("Repeat menu")
struct RepeatMenuTests {
    /// An event without guests (a change to one with guests waits for Send update).
    func open(_ m: AppModel, recurring: Bool = false) -> CalendarEvent {
        let e = m.layout.timed.flatMap { $0 }.map(\.event).first { m.editorCanEdit($0) && !$0.isAllDay && $0.isRecurring == recurring && $0.attendees.isEmpty }!
        m.select(eventID: e.id)
        return e
    }

    @Test func aSingleEventBecomesASeries() throws {
        let m = makeModelV4()
        let e = open(m, recurring: false)
        let rows = m.repeatMenuRows()
        #expect(rows.first?.checked == true && rows.first?.text == "Does not repeat")
        let weekly = try #require(rows.first { $0.text.hasPrefix("Every week on") })
        m.setSelectedRepeat(weekly.rule!)
        let now = try #require(m.selectedEvent)
        #expect(now.id == e.id && now.isRecurring && m.store.series(of: now).count > 50)
        #expect(m.repeatMenuRows().first { $0.checked }?.key == weekly.key)
        #expect(m.overlay == nil, "a new rule asks no question")
    }

    @Test func withGuestsTheRuleWaitsForSendThenGoesToTheSeries() throws {
        let m = makeModelV4()
        let e = m.layout.timed.flatMap { $0 }.map(\.event).first { m.editorCanEdit($0) && !$0.isAllDay && !$0.isRecurring && m.buffersUpdates($0) }!
        m.select(eventID: e.id)
        m.setSelectedRepeat(Recurrence(frequency: .daily))
        #expect(m.panelState.unsent[e.id] != nil && m.store.series(of: e).count == 1)
        m.sendUnsent(notify: false)
        let series = try #require(m.selectedEvent)
        #expect(m.overlay == nil && m.store.series(of: series).count > 1)
        m.setSelectedRepeat(nil)
        m.sendUnsent(notify: true)
        #expect(m.overlay == nil, "a new rule alone asks no question")
        let single = try #require(m.selectedEvent)
        #expect(m.store.series(of: single).count == 1)
    }

    @Test func doesNotRepeatLeavesOneEvent() throws {
        let m = makeModelV4()
        _ = open(m)
        m.setSelectedRepeat(Recurrence(frequency: .daily))
        let e = try #require(m.selectedEvent)
        #expect(m.store.series(of: e).count > 1 && m.store.repeats(e))
        m.setSelectedRepeat(nil)
        let now = try #require(m.selectedEvent)
        #expect(!now.isRecurring && m.store.series(of: now).count == 1 && now.start == e.start)
    }

    @Test func theStopOpensTheMenuByKeyboard() {
        let m = makeModelV4()
        _ = open(m)
        #expect(m.panelStops.contains(.repeats))
        m.activatePanelStop(.repeats)
        #expect(m.panelMenus.open == .repeats && m.panelMenus.highlight == "menu:rep:0")
    }
}
