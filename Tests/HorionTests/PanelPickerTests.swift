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

    // MARK: Repeat

    @Test func repeatRules() {
        let math = DemoDataV4.math
        let thu = math.date(year: 2026, month: 11, day: 26, hour: 9)
        #expect(RepeatRules.rule(.weekly, start: thu, math: math) == Recurrence(frequency: .weekly, weekdays: [5]))
        #expect(RepeatRules.choice(of: Recurrence(frequency: .weekly), start: thu, math: math) == .weekly, "no days: the start's day")
        #expect(RepeatRules.choice(of: Recurrence(frequency: .weekly, interval: 3), start: thu, math: math) == nil, "custom")
        #expect(RepeatRules.choice(of: nil, start: thu, math: math) == RepeatChoice.none)
        let fmt = Fmt(math: math)
        #expect(RepeatRules.label(.biweekly, start: thu, fmt: fmt) == "Every 2 weeks on Thu" && RepeatRules.label(.monthly, start: thu, fmt: fmt) == "Monthly on day 26")
        // occurrences
        let weekdays = RepeatRules.starts(RepeatRules.rule(.weekdays, start: thu, math: math)!, first: thu, through: math.addDays(thu, 7), math: math)
        #expect(weekdays.map { math.calendar.component(.weekday, from: $0) } == [5, 6, 2, 3, 4, 5])
        let jan31 = math.date(year: 2027, month: 1, day: 31, hour: 8)
        let monthly = RepeatRules.starts(Recurrence(frequency: .monthly), first: jan31, through: math.addMonths(jan31, 3), math: math)
        #expect(monthly.map(math.month) == [1, 3], "no 31st in February or April")
        // the custom rows
        let every2 = RepeatRules.stepInterval(nil, by: 1, start: thu, math: math)
        #expect(every2 == Recurrence(frequency: .weekly, interval: 2, weekdays: [5]))
        #expect(RepeatRules.stepFrequency(every2, by: 1, start: thu, math: math).frequency == .monthly)
        let ends = RepeatRules.stepUntil(every2, by: 2, start: thu, math: math)
        #expect(ends.until.map { math.month($0) == 1 && math.day($0) == 26 } == true)
        #expect(RepeatRules.stepUntil(RepeatRules.stepUntil(ends, by: -1, start: thu, math: math), by: -1, start: thu, math: math).until == nil)
        let until = RepeatRules.starts(Recurrence(frequency: .daily, until: ends.until), first: thu, through: math.addDays(thu, 400), math: math)
        #expect(until.count == 62, "26 Nov to 26 Jan, both in")
    }

    @Test func repeatMenuByKeyboardMakesASeries() {
        let m = makeModelV4()
        let e = open(m)
        #expect(e.recurrence == nil && m.panelStops.contains(.repeats))
        m.focusPanelStop(.repeats)
        #expect(key(m, "\r", ShortcutResolver.keyReturn))
        #expect(m.panelMenus.open == .repeats && m.panelMenus.highlight == "rep:none")
        #expect(key(m, "", ShortcutResolver.keyDown) && key(m, "", ShortcutResolver.keyDown) && key(m, "", ShortcutResolver.keyDown))
        #expect(m.panelMenus.highlight == "rep:weekly")
        #expect(key(m, "\r", ShortcutResolver.keyReturn))
        let wd = m.math.calendar.component(.weekday, from: e.start)
        #expect(m.selectedEventID == e.id && m.selectedEvent?.recurrence == Recurrence(frequency: .weekly, weekdays: [wd]))
        let series = m.store.series(of: m.selectedEvent!)
        #expect(series.count > 50 && series.allSatisfy { m.math.calendar.component(.weekday, from: $0.start) == wd })
        #expect(PanelText.editorRepeats(m.selectedEvent!, m.fmt)?.hasPrefix("Every week on") == true)

        // custom: every 2 weeks, ending in two months
        #expect(key(m, " ", 49) && m.panelMenus.open == .repeats && m.panelMenus.highlight == "rep:weekly")
        while m.panelMenus.highlight != "rep:every" { _ = key(m, "", ShortcutResolver.keyDown) }
        #expect(key(m, "", ShortcutResolver.keyRight))
        #expect(m.selectedEvent?.recurrence?.interval == 2 && m.panelMenus.open == .repeats, "the menu stays open on a custom row")
        #expect(key(m, "", ShortcutResolver.keyDown) && key(m, "", ShortcutResolver.keyDown))
        #expect(key(m, "", ShortcutResolver.keyRight) && key(m, "", ShortcutResolver.keyRight))
        #expect(m.selectedEvent?.recurrence?.until != nil)
        let ended = m.store.series(of: m.selectedEvent!)
        #expect((4...5).contains(ended.count), "every 2 weeks for 2 months")
        #expect(key(m, "\u{1b}", ShortcutResolver.keyEscape) && m.panelMenus.open == nil)

        // and back: does not repeat
        m.openRepeatMenu()
        m.setSelectedRecurrence(nil)
        #expect(m.selectedEvent?.recurrence == nil && m.selectedEvent?.seriesID == nil && m.selectedEventID == e.id)
    }

    @Test func repeatRuleChangeOfASeries() throws {
        let m = makeModelV4()
        let wg = try #require(SnapshotV4.event(m, "wg"))
        m.select(eventID: wg.id)
        let before = m.store.series(of: wg).count
        #expect(before >= 1 && wg.seriesID != nil)
        m.setSelectedRecurrence(RepeatRules.rule(.daily, start: wg.start, math: m.math))
        #expect(m.overlay == nil, "a rule change does not ask which occurrences: it is the series'")
        #expect(m.selectedEvent?.recurrence?.frequency == .daily && m.store.series(of: m.selectedEvent!).count > before)
    }

    @Test func storesWriteTheRule() {
        let zone = TimeZone(identifier: "Europe/Berlin")!
        let old = CalendarEvent(calendarID: "c", title: "x", start: Date(timeIntervalSince1970: 1_800_000_000), end: Date(timeIntervalSince1970: 1_800_003_600))
        var new = old
        new.recurrence = Recurrence(frequency: .weekly, interval: 2, weekdays: [2])
        #expect(GoogleMapping.patch(old: old, new: new, zone: zone)?.recurrence == ["RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO"])
        #expect(GoogleMapping.patch(old: new, new: old, zone: zone)?.recurrence == [], "an empty list ends repeating")
        let r = Recurrence(frequency: .monthly, interval: 3, until: Date(timeIntervalSince1970: 1_900_000_000))
        #expect(EventKitStore.convert(EventKitStore.rule(r)) == r)
        let w = Recurrence(frequency: .weekly, weekdays: [2, 4])
        #expect(EventKitStore.convert(EventKitStore.rule(w)) == w)
    }

    @Test func aNewEventSavesItsRule() {
        let m = makeModelV4()
        let s = m.math.date(on: m.visibleStart, minutes: 7 * 60)
        m.createEvent(start: s, end: s.addingTimeInterval(1800))
        #expect(m.isDraftOpen)
        m.setSelectedTitle("Standup")
        m.setSelectedRecurrence(RepeatRules.rule(.weekdays, start: s, math: m.math))
        #expect(m.selectedEvent?.recurrence?.weekdays == [2, 3, 4, 5, 6])
        m.saveDraft()
        let made = m.store.searchCorpus(around: s).filter { $0.title == "Standup" }
        #expect(made.count > 100 && Set(made.compactMap(\.seriesID)).count == 1)
    }

    // MARK: Participants

    @Test func guestsByKeyboard() throws {
        let m = makeModelV4()
        let e = open(m)
        #expect(m.panelStops.contains(.guest))
        focus(m, .guest)
        m.guestQueryChanged("")
        let list = m.guestSuggestions("")
        try #require(list.count > 2)
        #expect(m.highlightedGuest == nil, "Return adds the first one until the arrows move")
        #expect(key(m, "", ShortcutResolver.keyDown, typing: true))
        #expect(m.highlightedGuest == list[1])
        #expect(key(m, "", ShortcutResolver.keyDown, typing: true) && key(m, "", ShortcutResolver.keyUp, typing: true))
        #expect(m.highlightedGuest == list[1])
        m.addGuest(m.highlightedGuest!)
        #expect(m.selectedEvent!.attendees.contains { $0.email == list[1].email } && m.selectedEvent!.attendees.count == e.attendees.count + 1)
        #expect(m.panelMenus.highlight == nil && m.panelMenus.open == nil)
        // a typed address that nobody has
        m.addGuest("new.person@example.org")
        #expect(m.selectedEvent!.attendees.contains { $0.email == "new.person@example.org" })
    }

    @Test func eventKitCannotAddGuestsAndSaysWhere() throws {
        let m = makeModelV4()
        try #require(m.store is DemoStore)
        (m.store as! DemoStore).canEditParticipants = false
        _ = open(m)
        #expect(!m.panelStops.contains(.guest), "no guest field to Tab to")
        m.openAccountsForGuests()
        #expect(m.overlay == .settings && m.services.settingsPage == .accounts)
    }
}
