import Testing
import Foundation
import HorionKit
@testable import Horion

/// The panel's pickers (Notion Calendar's level of function), by mouse and by keyboard.
@MainActor
@Suite("Panel pickers")
struct PanelPickerTests {
    let r = KeyRouter()
    func key(_ m: AppModel, _ c: String, _ code: UInt16, shift: Bool = false, typing: Bool = false) -> Bool {
        r.handle(KeyInput(characters: c, keyCode: code, shift: shift), typing: typing, window: nil, model: m)
    }
    func open(_ m: AppModel) -> CalendarEvent {
        let e = m.layout.timed.flatMap { $0 }.map(\.event).first { m.editorCanEdit($0) && !$0.isAllDay && !$0.isRecurring && $0.attendees.isEmpty }!
        m.select(eventID: e.id)
        return e
    }
    /// What the editor does when a field takes the keyboard (the view calls it from its focus change).
    func focus(_ m: AppModel, _ f: PanelFocus) {
        m.focusPanelStop(f.stop)
        m.panelFieldFocusChanged(f)
    }

    // MARK: Times

    @Test func timeSlots() {
        #expect(TimeSlots.starts.count == 96 && TimeSlots.starts.first == 0 && TimeSlots.starts.last == 1425)
        #expect(TimeSlots.ends(after: 570).first == 585 && TimeSlots.ends(after: 570).last == 1440)
        #expect(TimeSlots.ends(after: 575).first == 585, "an odd start: the end list starts at the next step")
        #expect(TimeSlots.slot(for: 622, in: TimeSlots.starts) == 615)
        #expect(TimeSlots.move(615, by: -1, in: TimeSlots.starts) == 600)
        #expect(TimeSlots.move(0, by: -1, in: TimeSlots.starts) == 0, "the list does not wrap")
        #expect(TimeSlots.move(nil, by: 1, in: TimeSlots.starts) == 0)
    }

    @Test func startListOpensOnTheFieldAndPicksByKeyboard() {
        let m = makeModelV4()
        let e = open(m)
        let start = m.math.minutesSinceMidnight(e.start)
        focus(m, .start)
        #expect(m.panelMenus.open == .startTime)
        #expect(m.highlightedMinutes == TimeSlots.slot(for: start, in: TimeSlots.starts), "the list opens on the current time")
        #expect(!key(m, "\r", ShortcutResolver.keyReturn, typing: true), "before the arrows, Return is the field's (it commits the typed text)")
        #expect(key(m, "", ShortcutResolver.keyDown, typing: true))
        #expect(key(m, "", ShortcutResolver.keyDown, typing: true))
        let tick = m.panelMenus.pickTick
        #expect(key(m, "\r", ShortcutResolver.keyReturn, typing: true))
        let picked = TimeSlots.slot(for: start, in: TimeSlots.starts)! + 30
        #expect(m.math.minutesSinceMidnight(m.selectedEvent!.start) == picked)
        #expect(m.selectedEvent!.durationMinutes == e.durationMinutes, "a new start keeps the length")
        #expect(m.panelMenus.open == nil && m.panelMenus.pickTick == tick + 1 && m.panelMenus.stop == .start, "the field keeps the keyboard")
        // Down opens it again, Esc closes it and the field stays
        #expect(key(m, "", ShortcutResolver.keyDown, typing: true) && m.panelMenus.open == .startTime)
        #expect(key(m, "\u{1b}", ShortcutResolver.keyEscape, typing: true))
        #expect(m.panelMenus.open == nil && m.panelMenus.stop == .start && m.selectedEventID == e.id)
    }

    @Test func endListShowsLengthsAndFollowsTyping() {
        let m = makeModelV4()
        let e = open(m)
        focus(m, .end)
        #expect(m.panelMenus.open == .endTime)
        let start = m.math.minutesSinceMidnight(e.start)
        #expect(m.timeChoices(.endTime).first == (start / 15 + 1) * 15)
        #expect(m.timeLength(start + 180) == "3 h" && m.timeLength(start + 195) == "3 h 15 min" && m.timeLength(start + 45) == "45 min")
        m.fieldPickerTyped(.end, "2210")
        #expect(m.highlightedMinutes == 22 * 60 + 0)
        m.fieldPickerTyped(.end, "22:20")
        #expect(m.highlightedMinutes == 22 * 60 + 15, "a typed time between steps shows the step before it")
        // a click on a row
        m.pickTime(.endTime, 23 * 60)
        #expect(m.math.minutesSinceMidnight(m.selectedEvent!.end) == 23 * 60 && m.panelMenus.open == nil)
    }

    @Test func tabClosesTheListAndMovesOn() {
        let m = makeModelV4()
        _ = open(m)
        focus(m, .start)
        #expect(key(m, "\t", ShortcutResolver.keyTab, typing: true))
        #expect(m.panelMenus.open == nil && m.panelMenus.stop == .end)
    }

    // MARK: Date

    @Test func dateMiniMonthByKeyboard() {
        let m = makeModelV4()
        let e = open(m)
        let math = m.math
        focus(m, .date)
        #expect(m.panelMenus.open == .datePicker)
        #expect(m.panelMenus.pickDay == math.startOfDay(e.start) && m.panelMenus.pickMonth == math.startOfMonth(e.start))
        #expect(!key(m, "", ShortcutResolver.keyRight, typing: true), "before Up or Down, Left and Right move the caret")
        #expect(key(m, "", ShortcutResolver.keyDown, typing: true))
        #expect(key(m, "", ShortcutResolver.keyRight, typing: true))
        #expect(m.panelMenus.pickDay == math.addDays(math.startOfDay(e.start), 8))
        #expect(key(m, "", AppModel.keyPageDown, typing: true))
        #expect(m.panelMenus.pickMonth.map(math.month) == math.month(math.addDays(e.start, 8)) % 12 + 1, "Page Down: a month on, the month follows")
        #expect(key(m, "", AppModel.keyPageUp, typing: true))
        #expect(key(m, "\r", ShortcutResolver.keyReturn, typing: true))
        let picked = math.addDays(math.startOfDay(e.start), 8)
        #expect(math.isSameDay(m.selectedEvent!.start, picked))
        #expect(math.minutesSinceMidnight(m.selectedEvent!.start) == math.minutesSinceMidnight(e.start), "the time stays")
        #expect(m.panelMenus.open == nil && m.panelMenus.stop == .date)
    }

    @Test func dateMiniMonthFollowsTypingAndClicks() {
        let m = makeModelV4()
        let e = open(m)
        let math = m.math
        focus(m, .date)
        m.fieldPickerTyped(.date, "14 Nov")
        #expect(m.panelMenus.pickDay.map { math.day($0) == 14 && math.month($0) == 11 } == true)
        #expect(m.panelMenus.pickMonth.map { math.month($0) } == 11)
        m.stepPickMonth(1)
        #expect(m.panelMenus.pickMonth.map { math.month($0) } == 12)
        let day = math.date(year: math.year(e.start), month: 12, day: 3)
        m.pickDate(day)
        #expect(math.isSameDay(m.selectedEvent!.start, day) && m.panelMenus.open == nil)
    }

    // MARK: Time zone

    @Test func zoneListNamesAndSearch() {
        #expect(TimeZoneList.offset(3600) == "GMT+01:00" && TimeZoneList.offset(-16200) == "GMT-04:30" && TimeZoneList.offset(19800) == "GMT+05:30")
        #expect(TimeZoneList.city("America/Argentina/Buenos_Aires") == "Buenos Aires")
        let winter = DemoDataV4.math.date(year: 2026, month: 11, day: 26)
        let all = TimeZoneList.all(at: winter)
        let berlin = all.first { $0.id == "Europe/Berlin" }
        #expect(berlin?.offset == "GMT+01:00" && berlin?.name == "Central European Standard Time" && berlin?.city == "Berlin")
        #expect(all.map(\.seconds) == all.map(\.seconds).sorted(), "by offset")
        #expect(!all.contains { $0.id.hasPrefix("Etc/") || $0.name.hasPrefix("GMT") })
        #expect(TimeZoneList.filter(all, "berlin").first?.id == "Europe/Berlin")
        #expect(TimeZoneList.filter(all, "new york").first?.id == "America/New_York")
        #expect(TimeZoneList.filter(all, "gmt+1").contains { $0.id == "Europe/Berlin" })
        #expect(TimeZoneList.filter(all, "zürich").contains { $0.id == "Europe/Zurich" }, "accents do not matter")
        let summer = DemoDataV4.math.date(year: 2026, month: 7, day: 1)
        #expect(TimeZoneList.entry("Europe/Berlin", at: summer)?.offset == "GMT+02:00")
    }

    @Test func zonePickerByKeyboard() {
        let m = makeModelV4()
        let e = open(m)
        #expect(m.panelStops.contains(.timeZone))
        m.focusPanelStop(.timeZone)
        #expect(key(m, "\r", ShortcutResolver.keyReturn))
        #expect(m.panelMenus.open == .timeZone && m.panelMenus.highlight == "tz:\(e.timeZoneID)")
        for c in "tokyo" { #expect(key(m, String(c), UInt16(0))) }
        #expect(m.panelMenus.zoneQuery == "tokyo" && m.panelMenus.highlight == "tz:Asia/Tokyo")
        #expect(key(m, "", ShortcutResolver.keyDelete) && m.panelMenus.zoneQuery == "toky")
        #expect(key(m, "\r", ShortcutResolver.keyReturn))
        #expect(m.selectedEvent?.timeZoneID == "Asia/Tokyo" && m.panelMenus.open == nil && m.panelMenus.stop == .timeZone)
        #expect(m.selectedEvent?.start == e.start, "the moment stays; the zone says where it is kept")
        #expect(m.zoneLabel(m.selectedEvent!).city == "Tokyo" && m.zoneLabel(m.selectedEvent!).times != nil)
        // the mouse: the button opens the list, typing still searches it
        m.panelMenus.stop = nil
        m.openZonePicker()
        #expect(m.panelMenus.open == .timeZone && m.panelMenus.zoneQuery.isEmpty)
        #expect(key(m, "b", UInt16(11)) && m.panelMenus.zoneQuery == "b")
        #expect(key(m, "\u{1b}", ShortcutResolver.keyEscape) && m.panelMenus.open == nil)
    }

    @Test func googleSendsTheNewZoneWithTheTimes() {
        let zone = TimeZone(identifier: "Europe/Berlin")!
        let old = CalendarEvent(calendarID: "c", title: "x", start: Date(timeIntervalSince1970: 1_800_000_000), end: Date(timeIntervalSince1970: 1_800_003_600))
        var new = old
        new.timeZoneID = "Asia/Tokyo"
        let g = GoogleMapping.patch(old: old, new: new, zone: zone)
        #expect(g?.start?.timeZone == "Asia/Tokyo" && g?.end?.timeZone == "Asia/Tokyo")
    }
}
