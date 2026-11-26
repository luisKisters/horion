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
