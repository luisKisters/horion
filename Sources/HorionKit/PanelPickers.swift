import Foundation

/// The time lists under the panel's start and end fields: 15-minute steps, minutes since midnight.
public enum TimeSlots {
    public static let step = 15

    /// 00:00 ... 23:45.
    public static let starts: [Int] = Array(stride(from: 0, to: 1440, by: step))

    /// The step after the start ... 24:00 (the event stays inside its day).
    public static func ends(after start: Int) -> [Int] {
        let first = (max(0, start) / step + 1) * step
        return first > 1440 ? [] : Array(stride(from: first, through: 1440, by: step))
    }

    /// The row the list shows for a time: the last step at or before it (the first row for a time before them all).
    public static func slot(for minutes: Int, in list: [Int]) -> Int? {
        list.last { $0 <= minutes } ?? list.first
    }

    /// The row `by` rows away from `from`, kept inside the list (no wrap: the list is long).
    public static func move(_ from: Int?, by d: Int, in list: [Int]) -> Int? {
        guard !list.isEmpty else { return nil }
        guard let from, let i = list.firstIndex(of: from) ?? list.lastIndex(where: { $0 <= from }) else { return d >= 0 ? list.first : list.last }
        return list[min(max(i + d, 0), list.count - 1)]
    }
}

/// The panel's time zone list: "GMT+01:00  Central European Standard Time – Berlin", by offset, searchable.
public struct TimeZoneEntry: Hashable, Sendable {
    public var id: String
    /// "GMT+01:00" (at the event's start: daylight saving counts)
    public var offset: String
    /// "Central European Standard Time"
    public var name: String
    /// "Berlin", "New York"
    public var city: String
    public var seconds: Int
}

public enum TimeZoneList {
    /// Every region zone (no "Etc/GMT+3", no bare abbreviations), by offset, then name, then city.
    public static func all(at date: Date) -> [TimeZoneEntry] {
        TimeZone.knownTimeZoneIdentifiers.filter { $0.contains("/") && !$0.hasPrefix("Etc/") }
            .compactMap { entry($0, at: date) }
            .sorted { ($0.seconds, $0.name, $0.city) < ($1.seconds, $1.name, $1.city) }
    }

    public static func entry(_ id: String, at date: Date) -> TimeZoneEntry? {
        guard let tz = TimeZone(identifier: id) else { return nil }
        let s = tz.secondsFromGMT(for: date)
        let style: NSTimeZone.NameStyle = tz.isDaylightSavingTime(for: date) ? .daylightSaving : .standard
        let en = Locale(identifier: "en_US")
        // some zones have no name of their own ("GMT+01:00"): the generic one ("United Kingdom Time"), else the region
        var name = tz.localizedName(for: style, locale: en) ?? id
        if name.hasPrefix("GMT") { name = tz.localizedName(for: .generic, locale: en).flatMap { $0.hasPrefix("GMT") ? nil : $0 } ?? region(id) }
        return TimeZoneEntry(id: id, offset: offset(s), name: name, city: city(id), seconds: s)
    }

    /// "Europe/Guernsey" -> "Europe"
    static func region(_ id: String) -> String { String(id.split(separator: "/").first ?? Substring(id)).replacingOccurrences(of: "_", with: " ") }

    /// "Europe/Berlin" -> "Berlin", "America/Argentina/Buenos_Aires" -> "Buenos Aires"
    public static func city(_ id: String) -> String {
        String(id.split(separator: "/").last ?? Substring(id)).replacingOccurrences(of: "_", with: " ")
    }

    /// 3600 -> "GMT+01:00", -16200 -> "GMT-04:30"
    public static func offset(_ seconds: Int) -> String {
        let m = abs(seconds) / 60
        return String(format: "GMT%@%02d:%02d", seconds < 0 ? "-" : "+", m / 60, m % 60)
    }

    /// Every word of the query is in the city, the zone's name, its id or its offset ("berlin", "central eu", "gmt+1", "+05:30").
    public static func filter(_ list: [TimeZoneEntry], _ query: String) -> [TimeZoneEntry] {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return list }
        func fold(_ s: String) -> String { s.lowercased().folding(options: .diacriticInsensitive, locale: nil) }
        let q = words.map(fold)
        // the city first, then a word that starts with the query, then the rest (each group by offset)
        var city: [TimeZoneEntry] = [], word: [TimeZoneEntry] = [], rest: [TimeZoneEntry] = []
        for e in list {
            let short = e.offset.replacingOccurrences(of: ":00", with: "").replacingOccurrences(of: "+0", with: "+").replacingOccurrences(of: "-0", with: "-")
            let hay = fold("\(e.city) \(e.name) \(e.id) \(e.offset) \(short)")
            guard q.allSatisfy(hay.contains) else { continue }
            let tokens = hay.split { $0 == " " || $0 == "/" || $0 == "-" || $0 == "_" }
            if fold(e.city).hasPrefix(q.joined(separator: " ")) { city.append(e) }
            else if q.allSatisfy({ w in tokens.contains { $0.hasPrefix(w) } }) { word.append(e) }
            else { rest.append(e) }
        }
        return city + word + rest
    }
}

/// The panel's Repeat menu: the common rules for an event's start, and the custom ones (every N days, weeks, months, years; an end).
public enum RepeatChoice: String, CaseIterable, Hashable, Sendable {
    case none, daily, weekdays, weekly, biweekly, monthly, yearly
}

public enum RepeatRules {
    /// The rule a choice makes for an event starting at `start`. `until` (a custom end) is kept.
    public static func rule(_ c: RepeatChoice, start: Date, math: CalendarMath, until: Date? = nil) -> Recurrence? {
        let wd = math.calendar.component(.weekday, from: start)
        switch c {
        case .none: return nil
        case .daily: return Recurrence(frequency: .daily, until: until)
        case .weekdays: return Recurrence(frequency: .weekly, weekdays: [2, 3, 4, 5, 6], until: until)
        case .weekly: return Recurrence(frequency: .weekly, weekdays: [wd], until: until)
        case .biweekly: return Recurrence(frequency: .weekly, interval: 2, weekdays: [wd], until: until)
        case .monthly: return Recurrence(frequency: .monthly, until: until)
        case .yearly: return Recurrence(frequency: .yearly, until: until)
        }
    }

    /// Which common rule `r` is (its end left aside), nil for a custom one.
    public static func choice(of r: Recurrence?, start: Date, math: CalendarMath) -> RepeatChoice? {
        guard var r else { return RepeatChoice.none }
        r.until = nil
        let wd = math.calendar.component(.weekday, from: start)
        if r.frequency == .weekly && r.weekdays.isEmpty { r.weekdays = [wd] }
        return RepeatChoice.allCases.first { $0 != .none && rule($0, start: start, math: math) == r }
    }

    /// "Does not repeat", "Every day", "Every weekday (Mon–Fri)", "Weekly on Thu", "Every 2 weeks on Thu", "Monthly on day 26",
    /// "Yearly on 26 Nov"
    public static func label(_ c: RepeatChoice, start: Date, fmt: Fmt) -> String {
        switch c {
        case .none: "Does not repeat"
        case .daily: "Every day"
        case .weekdays: "Every weekday (Mon\u{2013}Fri)"
        case .weekly: "Weekly on \(fmt.weekdayShort(start))"
        case .biweekly: "Every 2 weeks on \(fmt.weekdayShort(start))"
        case .monthly: "Monthly on day \(fmt.math.day(start))"
        case .yearly: "Yearly on \(fmt.math.day(start)) \(fmt.monthShort(start))"
        }
    }

    /// The custom rows: `r` with `interval` changed by `d` (1 ... 99). No rule yet: weekly on the start's day.
    public static func stepInterval(_ r: Recurrence?, by d: Int, start: Date, math: CalendarMath) -> Recurrence {
        var x = r ?? rule(.weekly, start: start, math: math)!
        x.interval = min(max(x.interval + d, 1), 99)
        return x
    }

    /// The next (or previous) unit: day, week, month, year. A weekly rule gets the start's day.
    public static func stepFrequency(_ r: Recurrence?, by d: Int, start: Date, math: CalendarMath) -> Recurrence {
        var x = r ?? rule(.weekly, start: start, math: math)!
        let all = Recurrence.Frequency.allCases
        let i = all.firstIndex(of: x.frequency) ?? 0
        x.frequency = all[(i + d + all.count) % all.count]
        x.weekdays = x.frequency == .weekly ? [math.calendar.component(.weekday, from: start)] : []
        return x
    }

    /// The end, a month at a time: never, then the end of the start's day 1, 2, 3 ... months on; back from the first month is never.
    public static func stepUntil(_ r: Recurrence?, by d: Int, start: Date, math: CalendarMath) -> Recurrence {
        var x = r ?? rule(.weekly, start: start, math: math)!
        let day = math.startOfDay(start)
        let months: Int = x.until.map { u in
            (1...240).first { math.addDays(math.addMonths(day, $0), 1) > u } ?? 240
        } ?? 0
        let n = max(0, months + d)
        x.until = n == 0 ? nil : math.addDays(math.addMonths(day, n), 1).addingTimeInterval(-1)
        return x
    }

    /// The starts of a rule's occurrences from the first one (`first`, included) to `limit`, at most `cap`.
    public static func starts(_ r: Recurrence, first: Date, through limit: Date, math: CalendarMath, cap: Int = 1000) -> [Date] {
        let end = min(limit, r.until ?? limit)
        let minutes = math.minutesSinceMidnight(first)
        let day0 = math.startOfDay(first)
        var out: [Date] = []
        func add(_ day: Date) -> Bool {
            let d = math.date(on: day, minutes: minutes)
            guard d <= end else { return false }
            if d >= first { out.append(d) }
            return out.count < cap
        }
        switch r.frequency {
        case .daily:
            var i = 0
            while add(math.addDays(day0, i * r.interval)) { i += 1 }
        case .weekly:
            let days = Set(r.weekdays.isEmpty ? [math.calendar.component(.weekday, from: first)] : r.weekdays)
            var week = math.startOfWeek(day0)
            weeks: while week <= end {
                for i in 0..<7 {
                    let d = math.addDays(week, i)
                    guard days.contains(math.calendar.component(.weekday, from: d)) else { continue }
                    if !add(d) { break weeks }
                }
                week = math.addDays(week, 7 * r.interval)
            }
        case .monthly, .yearly:
            let step = r.frequency == .monthly ? r.interval : 12 * r.interval
            let dom = math.day(day0)
            var i = 0
            while true {
                let m = math.addMonths(math.startOfMonth(day0), i * step)
                if m > end { break }
                let d = math.addDays(m, dom - 1)
                if math.isSameMonth(d, m), !add(d) { break }
                i += 1
            }
        }
        return out
    }
}
