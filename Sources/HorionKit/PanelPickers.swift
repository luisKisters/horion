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
