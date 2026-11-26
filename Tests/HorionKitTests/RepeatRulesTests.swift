import Testing
import Foundation
import HorionKit

@Suite("Repeat rules")
struct RepeatRulesTests {
    let math = CalendarMath()
    var cal: Calendar { math.calendar }
    func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 13) -> Date { cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h))! }

    @Test func choicesFollowTheStartWeekday() {
        let thu = at(2026, 11, 26)
        let c = RepeatRules.choices(start: thu, calendar: cal)
        #expect(c.first! == nil && c.count == 7)
        #expect(c[3] == Recurrence(frequency: .weekly, weekdays: [5]))
        #expect(RepeatRules.same(Recurrence(frequency: .weekly), c[3], start: thu, calendar: cal), "a weekly rule without days repeats on the start's day")
        #expect(!RepeatRules.same(c[3], c[4], start: thu, calendar: cal))
    }

    @Test func weeklyStartsKeepTheClockTimeOverDST() {
        let r = Recurrence(frequency: .weekly, weekdays: [5])
        let s = RepeatRules.starts(r, first: at(2026, 10, 15), calendar: cal, limit: at(2026, 11, 6))
        #expect(s.count == 4, "Oct 15, 22, 29 (after the change to winter time), Nov 5")
        #expect(s.allSatisfy { cal.component(.hour, from: $0) == 13 && cal.component(.weekday, from: $0) == 5 })
    }

    @Test func weekdaysEveryTwoWeeksAndUntil() {
        let mon = at(2026, 11, 23)
        let wd = RepeatRules.starts(Recurrence(frequency: .weekly, weekdays: [2, 3, 4, 5, 6]), first: at(2026, 11, 25), calendar: cal, limit: at(2026, 12, 1))
        #expect(wd.map { cal.component(.day, from: $0) } == [25, 26, 27, 30], "from the first start on, no weekend")
        let two = RepeatRules.starts(Recurrence(frequency: .weekly, interval: 2, weekdays: [2]), first: mon, calendar: cal, limit: at(2027, 1, 1))
        #expect(two.map { cal.component(.day, from: $0) } == [23, 7, 21])
        let until = RepeatRules.starts(Recurrence(frequency: .daily, until: at(2026, 11, 25, 13)), first: mon, calendar: cal, limit: at(2027, 1, 1))
        #expect(until.count == 3, "until counts its own day")
    }

    @Test func monthlySkipsMonthsWithoutTheDay() {
        let s = RepeatRules.starts(Recurrence(frequency: .monthly), first: at(2026, 1, 31), calendar: cal, limit: at(2026, 6, 1))
        #expect(s.map { cal.component(.month, from: $0) } == [1, 3, 5])
        let y = RepeatRules.starts(Recurrence(frequency: .yearly), first: at(2028, 2, 29), calendar: cal, limit: at(2033, 1, 1))
        #expect(y.map { cal.component(.year, from: $0) } == [2028, 2032])
    }

    @Test func googlePatchSendsTheRule() throws {
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        let e = CalendarEvent(id: "a", calendarID: "c", title: "Therapie", start: at(2026, 11, 26), end: at(2026, 11, 26, 14))
        var n = e
        n.recurrence = Recurrence(frequency: .weekly, weekdays: [5])
        #expect(try #require(GoogleMapping.patch(old: e, new: n, zone: berlin)).recurrence == ["RRULE:FREQ=WEEKLY;BYDAY=TH"])
        // an instance knows only that it repeats: "Does not repeat" clears the series' rules
        var inst = e
        inst.seriesID = "s"
        var single = inst
        single.seriesID = nil
        #expect(try #require(GoogleMapping.patch(old: inst, new: single, zone: berlin)).recurrence == [])
        #expect(GoogleMapping.patch(old: inst, new: inst, zone: berlin) == nil)
    }
}
