import Foundation

/// The editor's Repeat menu and the occurrences of a rule (the demo store expands its series with them).
public enum RepeatRules {
    /// The menu's rules for an event that starts at `start`, top to bottom: none, every day, every weekday, every week on the start's
    /// weekday, every 2 weeks on it, every month, every year.
    public static func choices(start: Date, calendar: Calendar) -> [Recurrence?] {
        let wd = calendar.component(.weekday, from: start)
        return [nil,
                Recurrence(frequency: .daily),
                Recurrence(frequency: .weekly, weekdays: [2, 3, 4, 5, 6]),
                Recurrence(frequency: .weekly, weekdays: [wd]),
                Recurrence(frequency: .weekly, interval: 2, weekdays: [wd]),
                Recurrence(frequency: .monthly),
                Recurrence(frequency: .yearly)]
    }

    /// The same rule for an event that starts at `start`: a weekly rule without days repeats on the start's weekday.
    public static func same(_ a: Recurrence?, _ b: Recurrence?, start: Date, calendar: Calendar) -> Bool {
        normalized(a, start: start, calendar: calendar) == normalized(b, start: start, calendar: calendar)
    }

    static func normalized(_ r: Recurrence?, start: Date, calendar: Calendar) -> Recurrence? {
        guard var r else { return nil }
        if r.frequency == .weekly {
            r.weekdays = r.weekdays.isEmpty ? [calendar.component(.weekday, from: start)] : Array(Set(r.weekdays)).sorted()
        } else {
            r.weekdays = []
        }
        return r
    }

    /// The starts of `r` from `first` on (`first` is the first one when it matches), before `limit` and up to the rule's end.
    /// A monthly or yearly rule skips the months and years without that day (the 31st, Feb 29). At most `max` starts.
    public static func starts(_ r: Recurrence, first: Date, calendar: Calendar, limit: Date, max: Int = 1000) -> [Date] {
        let end = min(limit, r.until.map { $0.addingTimeInterval(1) } ?? limit)
        var out: [Date] = []
        func add(_ d: Date) -> Bool {
            guard d < end, out.count < max else { return false }
            if d >= first { out.append(d) }
            return true
        }
        switch r.frequency {
        case .daily:
            var i = 0
            while let d = calendar.date(byAdding: .day, value: i * r.interval, to: first), add(d) { i += 1 }
        case .weekly:
            let days = Set(r.weekdays.isEmpty ? [calendar.component(.weekday, from: first)] : r.weekdays)
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: first)?.start ?? first
            let t = calendar.dateComponents([.hour, .minute, .second], from: first)
            var w = 0
            outer: while true {
                guard let ws = calendar.date(byAdding: .weekOfYear, value: w * r.interval, to: weekStart) else { break }
                for k in 0..<7 {
                    guard let day = calendar.date(byAdding: .day, value: k, to: ws) else { continue }
                    guard days.contains(calendar.component(.weekday, from: day)) else { continue }
                    // the start's clock time on that day (a DST change in between keeps it)
                    let d = calendar.date(bySettingHour: t.hour ?? 0, minute: t.minute ?? 0, second: t.second ?? 0, of: day) ?? day
                    if !add(d) { break outer }
                }
                w += 1
            }
        case .monthly, .yearly:
            let unit: Calendar.Component = r.frequency == .monthly ? .month : .year
            let day = calendar.component(.day, from: first), month = calendar.component(.month, from: first)
            var i = 0
            while out.count < max, let d = calendar.date(byAdding: unit, value: i * r.interval, to: first) {
                // `date(byAdding:)` clamps the 31st to the 30th: such months have no occurrence
                if calendar.component(.day, from: d) == day && (unit == .month || calendar.component(.month, from: d) == month) {
                    if !add(d) { break }
                } else if d >= end { break }
                i += 1
            }
        }
        return out
    }
}
