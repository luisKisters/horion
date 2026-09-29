import Foundation
import CalendrKit

/// Seed data. The week of Mon Sep 28 - Sun Oct 4 2026 mirrors design/reference/1-week-view.png; other weeks
/// get the same recurring rhythm plus deterministic one-off appointments so month view and search have content.
enum DemoData {
    static let math = CalendarMath(timeZone: TimeZone(identifier: "Europe/Berlin")!)
    static let refWeekStart = math.date(year: 2026, month: 9, day: 28)
    static let refWeekEnd = math.date(year: 2026, month: 10, day: 5)
    static let generateFrom = math.date(year: 2026, month: 6, day: 29)
    static let generateTo = math.date(year: 2027, month: 4, day: 5)

    // MARK: Accounts

    static let acc1 = "acc.personal", acc2 = "acc.services", acc3 = "acc.work"
    static let personal = "cal.personal", family = "cal.family", tasks = "cal.tasks", school = "cal.school"
    static let feiertage = "cal.feiertage", holidays = "cal.holidays", ferien = "cal.ferien"
    static let services = "cal.services", svcFeiertage = "cal.svc.feiertage", svcHolidays = "cal.svc.holidays", svcItaly = "cal.svc.italy"
    static let work = "cal.work", workHolidays = "cal.work.holidays"

    static let accounts: [CalendarAccount] = [
        CalendarAccount(id: acc1, name: "alex.rivera@example.com", calendars: [
            CalendarInfo(id: personal, accountID: acc1, title: "Personal", colorHex: "#5C88E4", isDefault: true),
            CalendarInfo(id: family, accountID: acc1, title: "Family", colorHex: "#EF8452"),
            CalendarInfo(id: tasks, accountID: acc1, title: "Tasks", colorHex: "#BDBCBC"),
            CalendarInfo(id: school, accountID: acc1, title: "School Board", colorHex: "#F1C55D"),
            CalendarInfo(id: feiertage, accountID: acc1, title: "Feiertage in Deutschland", colorHex: "#8236DD", icon: .feed, isWritable: false),
            CalendarInfo(id: holidays, accountID: acc1, title: "Holidays in Germany", colorHex: "#80CF93", icon: .feed, isWritable: false),
            CalendarInfo(id: ferien, accountID: acc1, title: "Ferien Berlin", colorHex: "#80CF93", icon: .feed, isWritable: false),
        ]),
        CalendarAccount(id: acc2, name: "alex.work@example.com", calendars: [
            CalendarInfo(id: services, accountID: acc2, title: "alex.work@example.com", colorHex: "#69A9DD"),
            CalendarInfo(id: svcFeiertage, accountID: acc2, title: "Feiertage in Deutschland", colorHex: "#80CF93", icon: .feed, isVisibleByDefault: false, isWritable: false),
            CalendarInfo(id: svcHolidays, accountID: acc2, title: "Holidays in Germany", colorHex: "#80CF93", icon: .feed, isVisibleByDefault: false, isWritable: false),
            CalendarInfo(id: svcItaly, accountID: acc2, title: "Holidays in Italy", colorHex: "#80CF93", icon: .feed, isVisibleByDefault: false, isWritable: false),
        ]),
        CalendarAccount(id: acc3, name: "alex@northwind.example.com", calendars: [
            CalendarInfo(id: work, accountID: acc3, title: "alex@northwind.example.com", colorHex: "#F1C55D"),
            CalendarInfo(id: workHolidays, accountID: acc3, title: "Holidays in Germany", colorHex: "#80CF93", icon: .feed, isWritable: false),
        ]),
    ]

    static let teammates: [Teammate] = [
        Teammate(name: "Sam Lee", email: "sam.lee@northwind.example.com"),
        Teammate(name: "Board Admin", email: "board@northwind.example.com"),
        Teammate(name: "IT Department", email: "noreply@northwind.example.com"),
        Teammate(name: "Max Mustermann", email: "test1@northwind.example.com"),
        Teammate(name: "Tine Tester", email: "test2@northwind.example.com"),
        Teammate(name: "Jordan Kim", email: "jordan.kim@northwind.example.com"),
        Teammate(name: "Billing Test", email: "billing-test@northwind.example.com"),
        Teammate(name: "Billing", email: "billing@northwind.example.com"),
        Teammate(name: "Taylor Reed", email: "taylor.reed@northwind.example.com"),
        Teammate(name: "Casey Morgan", email: "social@northwind.example.com"),
        Teammate(name: "Chapter Berlin", email: "berlin@northwind.example.com"),
    ]

    // MARK: Helpers

    static func at(_ base: Date, _ hhmm: String) -> Date {
        let p = hhmm.split(separator: ":").compactMap { Int($0) }
        return math.date(on: base, minutes: p[0] * 60 + p[1])
    }
    static func day(_ m: Int, _ d: Int, year: Int = 2026) -> Date { math.date(year: year, month: m, day: d) }

    struct Series {
        var title: String
        var calendar: String
        var weekdays: [Int]              // Calendar weekday numbers, Sunday = 1
        var start: String, end: String
        var kind: EventKind = .event
        var location = "", notes = ""
        var colorHex: String?
        var until: Date?
        var skipHolidays = false
        var reminder: Int? = nil
    }

    static let schoolUntil = day(7, 9, year: 2027)
    static let classNotes = "Room 2.04, second floor."
    static let schoolLocation = "City School,\nMain St. 1, 10115 Berlin"

    static func school(_ t: String, _ wd: [Int], _ s: String, _ e: String) -> Series {
        Series(title: t, calendar: personal, weekdays: wd, start: s, end: e, location: schoolLocation, notes: t == "Politik" ? classNotes : "", until: schoolUntil, skipHolidays: true, reminder: 1)
    }

    // Calendar weekdays: Sun=1 Mon=2 Tue=3 Wed=4 Thu=5 Fri=6 Sat=7
    static var series: [Series] {
        let all = [2, 3, 4, 5, 6, 7, 1]
        return [
            school("Englisch", [2, 5], "08:00", "09:45"),
            school("Spanisch", [3, 6], "08:00", "09:45"),
            school("Biologie", [2], "14:35", "16:10"),
            school("Biologie", [3], "10:10", "11:50"),
            school("Kunst", [2, 5], "16:15", "17:50"),
            school("Mathe", [3], "12:00", "13:40"),
            school("Mathe", [5], "10:10", "11:50"),
            school("Politik", [3], "16:15", "17:50"),
            school("Politik", [4], "10:10", "11:50"),
            school("Deutsch", [4], "12:55", "14:30"),
            school("Deutsch", [5], "14:35", "16:10"),
            school("Geschichte", [4, 6], "14:35", "16:10"),
            school("Englisch", [6], "12:00", "13:40"),
            Series(title: "Ben / Alex", calendar: personal, weekdays: [3], start: "14:00", end: "15:00"),
            Series(title: "Coaching", calendar: personal, weekdays: [5], start: "13:00", end: "14:00"),
            Series(title: "Mia / Alex", calendar: personal, weekdays: [2, 3, 5, 6, 7, 1], start: "22:00", end: "22:30"),
            Series(title: "Meal Prep", calendar: tasks, weekdays: [2, 3, 4, 5, 6], start: "07:30", end: "07:45", kind: .task),
            Series(title: "Sportzeug", calendar: tasks, weekdays: [3, 4, 6], start: "07:30", end: "07:45", kind: .task),
            Series(title: "[P1] Daily stretch until done", calendar: tasks, weekdays: all, start: "18:00", end: "18:15", kind: .task),
            Series(title: "Water the plants", calendar: tasks, weekdays: all, start: "22:49", end: "23:00", kind: .task),
            Series(title: "[P0] Evening review, 10 minutes", calendar: tasks, weekdays: all, start: "23:00", end: "23:15", kind: .task),
        ]
    }

    static let holidayList: [(Date, Date?, String, String, [String])] = [   // start, endInclusive, title, calendar, extra
        (day(10, 3), nil, "Tag der Deutschen Einheit", feiertage, []),
        (day(10, 3), nil, "Day of German Unity", holidays, []),
        (day(10, 31), nil, "Reformationstag", feiertage, []),
        (day(12, 24), nil, "Heiligabend", feiertage, []),
        (day(12, 25), nil, "1. Weihnachtstag", feiertage, []),
        (day(12, 25), nil, "Christmas Day", holidays, []),
        (day(12, 26), nil, "2. Weihnachtstag", feiertage, []),
        (day(12, 26), nil, "Second Day of Christmas", holidays, []),
        (day(12, 31), nil, "Silvester", feiertage, []),
        (day(1, 1, year: 2027), nil, "Neujahr", feiertage, []),
        (day(1, 1, year: 2027), nil, "New Year's Day", holidays, []),
        (day(3, 8, year: 2027), nil, "Internationaler Frauentag", feiertage, []),
        (day(3, 26, year: 2027), nil, "Karfreitag", feiertage, []),
        (day(3, 28, year: 2027), nil, "Ostersonntag", feiertage, []),
        (day(7, 24), day(9, 5), "Sommerferien", ferien, []),
        (day(10, 19), day(10, 31), "Herbstferien", ferien, []),
        (day(12, 23), day(1, 2, year: 2027), "Weihnachtsferien", ferien, []),
        (day(2, 1, year: 2027), day(2, 6, year: 2027), "Winterferien", ferien, []),
    ]

    static func isSchoolBreak(_ d: Date) -> Bool {
        for (s, e, _, cal, _) in holidayList where cal == ferien || cal == feiertage {
            let end = e ?? s
            if d >= s && d <= end { return true }
        }
        return false
    }

    // MARK: Build

    static func buildEvents(dense: Bool = false) -> [CalendarEvent] {
        var out: [CalendarEvent] = []
        out.append(contentsOf: recurring())
        out.append(contentsOf: referenceWeekOneOffs())
        out.append(contentsOf: filler())
        out.append(contentsOf: holidayEvents())
        out.append(contentsOf: otherAccountEvents())
        if dense { out.append(contentsOf: denseEvents()) }
        return out.sorted { $0.start != $1.start ? $0.start < $1.start : $0.id < $1.id }
    }

    static func recurring() -> [CalendarEvent] {
        var out: [CalendarEvent] = []
        for (idx, s) in series.enumerated() {
            let sid = "series.\(idx)"
            let rule = Recurrence(frequency: .weekly, weekdays: s.weekdays.count == 7 ? [] : s.weekdays, until: s.until)
            var d = generateFrom
            while d < generateTo {
                defer { d = math.addDays(d, 1) }
                guard s.weekdays.contains(math.calendar.component(.weekday, from: d)) else { continue }
                if s.skipHolidays && isSchoolBreak(d) { continue }
                if let u = s.until, d > u { continue }
                var r = rule
                if s.weekdays.count == 7 { r = Recurrence(frequency: .daily, until: s.until) }
                out.append(CalendarEvent(id: "\(sid)@\(Int(d.timeIntervalSince1970))", seriesID: sid, calendarID: s.calendar, title: s.title,
                                         start: at(d, s.start), end: at(d, s.end), kind: s.kind, location: s.location, notes: s.notes,
                                         recurrence: r, reminderMinutes: s.reminder, colorHex: s.colorHex))
            }
        }
        return out
    }

    static func ev(_ id: String, _ cal: String, _ title: String, _ d: Date, _ s: String, _ e: String, kind: EventKind = .event,
                   status: ResponseStatus = .confirmed, color: String? = nil, bar2: String? = nil, location: String = "", notes: String = "") -> CalendarEvent {
        CalendarEvent(id: "ref.\(id)", calendarID: cal, title: title, start: at(d, s), end: at(d, e), kind: kind, status: status,
                      location: location, notes: notes, reminderMinutes: kind == .task ? nil : 1, colorHex: color, secondaryBarHex: bar2)
    }
    static func allDay(_ id: String, _ cal: String, _ title: String, _ from: Date, days: Int = 1, kind: EventKind = .event, notes: String = "") -> CalendarEvent {
        CalendarEvent(id: "ref.\(id)", calendarID: cal, title: title, start: from, end: math.addDays(from, days), isAllDay: true, kind: kind, notes: notes)
    }

    static let green = "#80CF93"
    static let brown = "#6F422C"

    static func referenceWeekOneOffs() -> [CalendarEvent] {
        let mon = refWeekStart, tue = day(9, 29), wed = day(9, 30), thu = day(10, 1), fri = day(10, 2), sat = day(10, 3), sun = day(10, 4)
        return [
            allDay("bei-stabilem", tasks, "[P1] Bei stabilem Internet...", mon, kind: .task),
            ev("bikeshop", tasks, "[P2] Call the bike shop", mon, "09:00", "09:15", kind: .task),
            ev("zahnarzt", tasks, "[P3] Call the library", mon, "10:00", "10:15", kind: .task),
            ev("dad-son", personal, "Dad <> Son", mon, "18:00", "19:00", color: green, bar2: brown),
            ev("chris", tasks, "[P1] Ask Chris: confirm the date", mon, "20:00", "20:15", kind: .task),
            ev("bouldern-fam", tasks, "[P0] Plan climbing + family dinner", mon, "20:10", "20:25", kind: .task),
            ev("fn", personal, "Fn?", mon, "21:00", "22:00"),
            ev("cousin", tasks, "[P2] Call cousin", mon, "21:40", "21:55", kind: .task),

            ev("friseur", tasks, "[P1] Friseurtermin machen", tue, "16:00", "16:15", kind: .task),
            ev("mia-chat", tasks, "[P1] Ask Mia when we meet next", tue, "20:00", "20:15", kind: .task),

            allDay("halbjaehriges", personal, "Halbjähriges", wed),
            ev("mia-halbjahr", personal, "WRITE MIA ABOUT ANNIVERSARY", wed, "07:30", "08:00"),
            CalendarEvent(id: "ref.bouldern", calendarID: personal, title: "Bouldern", start: at(wed, "16:30"), end: at(wed, "18:30"), status: .declined),
            ev("familienessen", personal, "Familienessen", wed, "16:30", "18:30", color: green, bar2: brown),
            ev("mia-alex-wed", personal, "Mia /  Alex", wed, "19:00", "22:30"),

            ev("wg-cleaning", personal, "Flat cleaning", thu, "18:00", "19:00"),
            ev("grants", school, "How to grants", thu, "19:00", "19:30", status: .tentative),
            ev("oet", school, "ÖT Meeting", thu, "19:00", "20:00"),
            ev("donnerstag", school, "Donnerstagmeeting", thu, "20:00", "21:30"),

            allDay("at", personal, "Maybe (see desc)", fri, days: 3, notes: "eher nicht"),
            allDay("noah", personal, "Noah away", fri, days: 3),
            allDay("subscription", tasks, "[P3] Renew subscription...", fri, kind: .task),
            ev("form", tasks, "[P2] Fill in the form", fri, "16:00", "16:15", kind: .task),

            allDay("a-lena", personal, "Lena birthday", sat),
            ev("lena-gratu", tasks, "Wish Lena a happy birthday", sat, "09:00", "09:15", kind: .task),
            ev("book", tasks, "[P3] Return the library book", sat, "18:00", "18:15", kind: .task),

            ev("run", personal, "morning run", sun, "09:45", "11:30", status: .tentative, color: green),
            ev("dana", tasks, "[P1] Text Dana", sun, "09:40", "09:55", kind: .task),
            ev("tickticks", tasks, "[P0?] Sunday calendar review", sun, "17:15", "17:30", kind: .task),
            ev("schnacken", personal, "Flat game night", sun, "19:00", "20:00", color: green, bar2: brown),
        ]
    }

    /// Deterministic one-off appointments in every week except the reference week.
    static func filler() -> [CalendarEvent] {
        struct Item { var title: String; var cal: String; var start: String; var mins: Int; var location = "" }
        let items: [Item] = [
            Item(title: "Zahnarzt", cal: personal, start: "09:30", mins: 45, location: "Clinic, Berlin"),
            Item(title: "Friseur", cal: personal, start: "15:00", mins: 60),
            Item(title: "Sprint Planning", cal: work, start: "10:00", mins: 90),
            Item(title: "Bouldern", cal: personal, start: "19:30", mins: 120, location: "Boulderklub Kreuzberg"),
            Item(title: "Call with Ben", cal: personal, start: "17:00", mins: 30),
            Item(title: "Vorstandssitzung", cal: work, start: "18:30", mins: 120),
            Item(title: "Familienessen", cal: family, start: "18:00", mins: 150, location: "Zuhause"),
            Item(title: "Elternabend", cal: school, start: "19:00", mins: 120, location: "City School"),
            Item(title: "Movie with Mia", cal: personal, start: "20:15", mins: 130, location: "Babylon Kino"),
            Item(title: "Steuerberater", cal: services, start: "11:00", mins: 60),
            Item(title: "Lauftraining", cal: personal, start: "07:00", mins: 60),
            Item(title: "Team Meetup", cal: work, start: "19:30", mins: 150),
        ]
        var out: [CalendarEvent] = []
        var seed: UInt64 = 42
        func rnd(_ n: Int) -> Int { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Int((seed >> 33) % UInt64(n)) }
        var week = generateFrom
        var i = 0
        while week < generateTo {
            defer { week = math.addDays(week, 7) }
            if math.startOfWeek(week) == refWeekStart { continue }
            for k in 0..<4 {
                let it = items[rnd(items.count)]
                let d = math.addDays(week, rnd(7))
                i += 1
                out.append(CalendarEvent(id: "fill.\(i)", calendarID: it.cal, title: it.title, start: at(d, it.start),
                                         end: at(d, it.start).addingTimeInterval(Double(it.mins) * 60), location: it.location, reminderMinutes: 10))
                _ = k
            }
            // A birthday or trip now and then.
            if rnd(3) == 0 {
                i += 1
                let d = math.addDays(week, rnd(7))
                out.append(CalendarEvent(id: "fill.\(i)", calendarID: personal, title: ["Grandma birthday", "Ella birthday", "Konzert Tempodrom", "Flug nach Rom", "Umzug Helfer"][rnd(5)],
                                         start: d, end: math.addDays(d, 1), isAllDay: true))
            }
        }
        return out
    }

    static func holidayEvents() -> [CalendarEvent] {
        var out: [CalendarEvent] = []
        for (i, h) in holidayList.enumerated() {
            if h.2 == "Tag der Deutschen Einheit" || h.2 == "Day of German Unity" { out.append(CalendarEvent(id: "ref.hol.\(h.3 == holidays ? "b" : "c")", calendarID: h.3, title: h.2, start: h.0, end: math.addDays(h.0, 1), isAllDay: true)); continue }
            let endEx = math.addDays(h.1 ?? h.0, 1)
            out.append(CalendarEvent(id: "hol.\(i)", calendarID: h.3, title: h.2, start: h.0, end: endEx, isAllDay: true))
        }
        return out
    }

    static func otherAccountEvents() -> [CalendarEvent] {
        // Events on the second/third account so their calendars are not empty (outside the reference week).
        var out: [CalendarEvent] = []
        var week = math.addDays(refWeekStart, 7)
        var i = 0
        while week < generateTo {
            defer { week = math.addDays(week, 14) }
            i += 1
            out.append(CalendarEvent(id: "svc.\(i)", calendarID: services, title: "Rechnungen prüfen", start: at(math.addDays(week, 1), "14:00"), end: at(math.addDays(week, 1), "15:00")))
            out.append(CalendarEvent(id: "work.\(i)", calendarID: work, title: "Team Weekly", start: at(math.addDays(week, 2), "17:00"), end: at(math.addDays(week, 2), "18:00"),
                                     recurrence: Recurrence(frequency: .weekly, interval: 2), participants: ["sam.lee@northwind.example.com"]))
        }
        return out
    }

    // MARK: Teammates

    static func teammateEvents() -> [CalendarEvent] {
        let titles = ["Standup", "1:1", "Planung", "Review", "Workshop", "Mittagspause", "Kundencall", "Design Sync", "Retro", "Fokuszeit"]
        var out: [CalendarEvent] = []
        for (ti, t) in teammates.enumerated() {
            var seed = UInt64(ti + 7) &* 2654435761
            func rnd(_ n: Int) -> Int { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Int((seed >> 33) % UInt64(n)) }
            var week = generateFrom
            var n = 0
            while week < generateTo {
                defer { week = math.addDays(week, 7) }
                for _ in 0..<(3 + rnd(3)) {
                    n += 1
                    let d = math.addDays(week, rnd(5))
                    let startMin = 8 * 60 + rnd(20) * 30
                    let dur = [30, 45, 60, 90][rnd(4)]
                    out.append(CalendarEvent(id: "tm.\(ti).\(n)", calendarID: "team:\(t.email)", title: titles[rnd(titles.count)],
                                             start: math.date(on: d, minutes: startMin), end: math.date(on: d, minutes: startMin + dur), ownerEmail: t.email))
                }
            }
        }
        return out.sorted { $0.start < $1.start }
    }

    // MARK: Dense data for --perf

    static func denseEvents() -> [CalendarEvent] {
        var out: [CalendarEvent] = []
        var seed: UInt64 = 99
        func rnd(_ n: Int) -> Int { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Int((seed >> 33) % UInt64(n)) }
        let cals = [personal, family, tasks, school, services, work]
        var week = math.addDays(math.startOfWeek(day(9, 28)), -60 * 7)
        for w in 0..<120 {
            for k in 0..<300 {
                let d = math.addDays(week, rnd(7))
                let start = rnd(23 * 4) * 15
                out.append(CalendarEvent(id: "dense.\(w).\(k)", calendarID: cals[rnd(cals.count)], title: "Dense event \(k)", start: math.date(on: d, minutes: start),
                                         end: math.date(on: d, minutes: start + [15, 30, 45, 60, 90, 120][rnd(6)]), kind: rnd(6) == 0 ? .task : .event))
            }
            week = math.addDays(week, 7)
        }
        return out
    }
}
