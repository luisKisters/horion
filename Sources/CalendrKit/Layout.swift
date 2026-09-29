import Foundation

// MARK: - Overlap layout (Notion-style cascade)

public struct TimeSpan: Sendable {
    public var id: String
    public var startMinute: Int
    public var endMinute: Int
    /// Short task-style items. They float over blocks that started well before them instead of squeezing them.
    public var isPill: Bool
    public init(id: String, startMinute: Int, endMinute: Int, isPill: Bool = false) {
        self.id = id; self.startMinute = startMinute; self.endMinute = endMinute; self.isPill = isPill
    }
}

public struct Placement: Equatable, Sendable {
    public init(id: String, column: Int, columns: Int, left: Double, width: Double, z: Int) { self.id = id; self.column = column; self.columns = columns; self.left = left; self.width = width; self.z = z }
    public var id: String
    public var column: Int
    public var columns: Int
    /// 0...1 of the day column width.
    public var left: Double
    public var width: Double
    public var z: Int
}

public enum OverlapLayout {
    /// Events shorter than this still occupy this much room when deciding whether they collide (they render as pills).
    public static let minLayoutMinutes = 15
    /// Cascade offsets measured from the reference: a later block starts ~37% into the column, a later short item ~53%.
    static let blockStep = 0.37
    static let shortStep = 0.53
    static let maxLastStart = 0.73
    static let maxCascadeWidth = 0.82
    /// A pill starting at least this long after a block did floats over it; earlier than that it shares columns.
    static let floatAfterMinutes = 60
    /// Left offset of a floating pill relative to the block it covers (8pt in a ~177pt column).
    static let floatInset = 0.045

    static func end(_ s: TimeSpan) -> Int { max(s.endMinute, s.startMinute + minLayoutMinutes) }
    static func overlaps(_ a: TimeSpan, _ b: TimeSpan) -> Bool { a.startMinute < end(b) && b.startMinute < end(a) }

    public static func layout(_ spans: [TimeSpan]) -> [Placement] {
        let blocks = spans.filter { !$0.isPill }
        var joined = blocks
        var floating: [TimeSpan] = []
        for p in spans where p.isPill {
            let hit = blocks.filter { overlaps(p, $0) }
            if hit.isEmpty || hit.contains(where: { p.startMinute - $0.startMinute < floatAfterMinutes }) { joined.append(p) }
            else { floating.append(p) }
        }
        var result = cascade(joined)
        let byID = Dictionary(uniqueKeysWithValues: result.map { ($0.id, $0) })
        for p in floating {
            let covered = blocks.filter { overlaps(p, $0) }.compactMap { byID[$0.id] }
            let left = min(0.9, (covered.map(\.left).max() ?? 0) + floatInset)
            result.append(Placement(id: p.id, column: 0, columns: 1, left: left, width: 1 - left, z: 100))
        }
        return result
    }

    static func cascade(_ spans: [TimeSpan]) -> [Placement] {
        let items = spans.enumerated().map { (i, s) in (index: i, span: s, end: end(s)) }.sorted {
            if $0.span.startMinute != $1.span.startMinute { return $0.span.startMinute < $1.span.startMinute }
            if $0.end != $1.end { return $0.end > $1.end }
            return $0.index < $1.index
        }
        var result: [Placement] = []
        result.reserveCapacity(items.count)
        var cluster: [(span: TimeSpan, end: Int, col: Int)] = []
        var clusterEnd = Int.min
        var columnEnds: [Int] = []

        func flush() {
            guard !cluster.isEmpty else { return }
            let n = columnEnds.count
            let laterAreShort = cluster.filter { $0.col > 0 }.allSatisfy { $0.span.isPill || $0.span.endMinute - $0.span.startMinute < 30 }
            let step = n > 1 ? min(laterAreShort ? shortStep : blockStep, maxLastStart / Double(n - 1)) : 0
            for c in cluster {
                let left = Double(c.col) * step
                let isLast = c.col == n - 1
                let width = n == 1 ? 1.0 : (isLast ? 1 - left : min(1 - left, maxCascadeWidth))
                result.append(Placement(id: c.span.id, column: c.col, columns: n, left: left, width: width, z: c.col))
            }
            cluster.removeAll(keepingCapacity: true)
            columnEnds.removeAll(keepingCapacity: true)
            clusterEnd = Int.min
        }

        for it in items {
            if it.span.startMinute >= clusterEnd { flush() }
            var col = columnEnds.firstIndex { $0 <= it.span.startMinute } ?? -1
            if col < 0 { columnEnds.append(it.end); col = columnEnds.count - 1 } else { columnEnds[col] = it.end }
            cluster.append((it.span, it.end, col))
            clusterEnd = max(clusterEnd, it.end)
        }
        flush()
        return result
    }
}

// MARK: - All-day lanes

public struct AllDayItem: Sendable {
    public var id: String
    /// Inclusive day indices relative to the visible range (may be outside 0..<dayCount, they are clipped).
    public var firstDay: Int
    public var lastDay: Int
    public init(id: String, firstDay: Int, lastDay: Int) { self.id = id; self.firstDay = firstDay; self.lastDay = lastDay }
}

public struct AllDayPlacement: Equatable, Sendable {
    public var id: String
    public var lane: Int
    public var firstDay: Int
    public var lastDay: Int
    public var clippedLeft: Bool
    public var clippedRight: Bool
    public var span: Int { lastDay - firstDay + 1 }
}

public struct AllDayLayout: Equatable, Sendable {
    public var placements: [AllDayPlacement]
    public var laneCount: Int
    public var dayCount: Int
    public static let empty = AllDayLayout(placements: [], laneCount: 0, dayCount: 0)

    /// Items visible with at most `maxLanes` lanes, and the number hidden per day.
    public func collapsed(maxLanes: Int) -> (visible: [AllDayPlacement], hiddenPerDay: [Int]) {
        var hidden = [Int](repeating: 0, count: dayCount)
        var vis: [AllDayPlacement] = []
        for p in placements {
            if p.lane < maxLanes { vis.append(p) } else {
                for d in p.firstDay...p.lastDay where d >= 0 && d < dayCount { hidden[d] += 1 }
            }
        }
        return (vis, hidden)
    }
}

public enum AllDayPacker {
    /// First-fit packing: longer spans first within the same start day, no gaps between lanes.
    public static func pack(_ items: [AllDayItem], dayCount: Int) -> AllDayLayout {
        guard dayCount > 0 else { return .empty }
        let clipped: [(idx: Int, id: String, a: Int, b: Int, cl: Bool, cr: Bool)] = items.enumerated().compactMap { i, it in
            guard it.lastDay >= 0, it.firstDay < dayCount else { return nil }
            return (i, it.id, max(0, it.firstDay), min(dayCount - 1, it.lastDay), it.firstDay < 0, it.lastDay > dayCount - 1)
        }.sorted {
            if $0.a != $1.a { return $0.a < $1.a }
            let l0 = $0.b - $0.a, l1 = $1.b - $1.a
            if l0 != l1 { return l0 > l1 }
            return $0.idx < $1.idx
        }
        var laneEnds: [Int] = []   // last occupied day per lane
        var out: [AllDayPlacement] = []
        for c in clipped {
            var lane = laneEnds.firstIndex { $0 < c.a } ?? -1
            if lane < 0 { laneEnds.append(c.b); lane = laneEnds.count - 1 } else { laneEnds[lane] = c.b }
            out.append(AllDayPlacement(id: c.id, lane: lane, firstDay: c.a, lastDay: c.b, clippedLeft: c.cl, clippedRight: c.cr))
        }
        return AllDayLayout(placements: out, laneCount: laneEnds.count, dayCount: dayCount)
    }
}

// MARK: - Range layout (what the views draw)

public struct PlacedEvent: Identifiable, Equatable, Sendable {
    public var id: String
    public var event: CalendarEvent
    public var dayIndex: Int
    public var startMinute: Int
    public var endMinute: Int
    public var placement: Placement
    public var continuesFromPrevious: Bool
    public var continuesToNext: Bool
    public var isPill: Bool { endMinute - startMinute < 30 }
}

public struct RangeLayout: Sendable {
    public var days: [Date]
    public var timed: [[PlacedEvent]]         // per day
    public var allDay: AllDayLayout
    public var allDayEvents: [String: CalendarEvent]
    public static let empty = RangeLayout(days: [], timed: [], allDay: .empty, allDayEvents: [:])

    public var timedCount: Int { timed.reduce(0) { $0 + $1.count } }
}

public enum RangeLayoutBuilder {
    /// Day index (relative to `days`) containing `t`, by binary search over the day starts: DST safe and much cheaper than Calendar.
    public static func dayIndex(_ t: Date, starts: [Date]) -> Int {
        var lo = 0, hi = starts.count
        while lo < hi { let m = (lo + hi) / 2; if starts[m] <= t { lo = m + 1 } else { hi = m } }
        return lo - 1      // -1 before the range, starts.count - 1 at/after the last start
    }

    public static func build(events: [CalendarEvent], days: [Date], math: CalendarMath) -> RangeLayout {
        let dayCount = days.count
        guard dayCount > 0 else { return .empty }
        let rangeEnd = math.addDays(days[dayCount - 1], 1)
        // Days that are not 24h long (DST changes) need wall-clock minutes; everything else can use elapsed time.
        let regular: [Bool] = (0..<dayCount).map { i in
            let next = i + 1 < dayCount ? days[i + 1] : rangeEnd
            return next.timeIntervalSince(days[i]) == 86_400
        }
        func minute(_ t: Date, dayIdx: Int) -> Int {
            if regular[dayIdx] { return Int(t.timeIntervalSince(days[dayIdx]) / 60) }
            return math.minutesSinceMidnight(t)
        }
        var perDaySpans = [[(event: CalendarEvent, s: Int, e: Int, from: Bool, to: Bool)]](repeating: [], count: dayCount)
        var allDayItems: [AllDayItem] = []
        var allDayMap: [String: CalendarEvent] = [:]

        for ev in events {
            if ev.isAllDay {
                let a = math.daysBetween(days[0], ev.start)
                var b = math.daysBetween(days[0], ev.end) - 1
                if b < a { b = a }
                guard b >= 0, a < dayCount else { continue }
                allDayItems.append(AllDayItem(id: ev.id, firstDay: a, lastDay: b))
                allDayMap[ev.id] = ev
                continue
            }
            let endInstant = ev.end > ev.start ? ev.end.addingTimeInterval(-1) : ev.end
            let first = ev.start < days[0] ? -1 : dayIndex(ev.start, starts: days)
            let last = endInstant < days[0] ? -1 : (endInstant >= rangeEnd ? dayCount : dayIndex(endInstant, starts: days))
            guard last >= 0, first < dayCount else { continue }
            let lo = max(0, first), hi = min(dayCount - 1, last)
            for d in lo...hi {
                let s = (d == first) ? minute(ev.start, dayIdx: d) : 0
                var e = (d == last) ? minute(ev.end, dayIdx: d) : 1440
                if d == last && ev.end > ev.start && e == 0 { e = 1440 }
                if d == last && ev.end == ev.start { e = s }
                perDaySpans[d].append((ev, s, e, d != first, d != last))
            }
        }

        var timed: [[PlacedEvent]] = []
        timed.reserveCapacity(dayCount)
        for d in 0..<dayCount {
            let spans = perDaySpans[d]
            let placements = OverlapLayout.layout(spans.enumerated().map {
                TimeSpan(id: String($0.offset), startMinute: $0.element.s, endMinute: $0.element.e,
                         isPill: $0.element.event.kind == .task && $0.element.e - $0.element.s < 30)
            })
            var byIdx = [Placement?](repeating: nil, count: spans.count)
            for p in placements { if let i = Int(p.id) { byIdx[i] = p } }
            var placed: [PlacedEvent] = []
            placed.reserveCapacity(spans.count)
            for (i, sp) in spans.enumerated() {
                guard let p = byIdx[i] else { continue }
                placed.append(PlacedEvent(id: "\(sp.event.id)|\(d)", event: sp.event, dayIndex: d, startMinute: sp.s,
                                          endMinute: sp.e, placement: p, continuesFromPrevious: sp.from, continuesToNext: sp.to))
            }
            // Paint order: lower z first so cascaded events sit on top.
            placed.sort { $0.placement.z != $1.placement.z ? $0.placement.z < $1.placement.z : $0.startMinute < $1.startMinute }
            timed.append(placed)
        }
        return RangeLayout(days: days, timed: timed, allDay: AllDayPacker.pack(allDayItems, dayCount: dayCount), allDayEvents: allDayMap)
    }
}

public enum FreeSlot {
    /// First start minute >= `from` on a `step` grid where [start, start+duration) collides with none of `busy`.
    /// Returns nil when the day has no room left.
    public static func next(from: Int, duration: Int, busy: [(start: Int, end: Int)], step: Int = 30) -> Int? {
        var s = ((max(0, from) + step - 1) / step) * step
        while s + duration <= 1440 {
            if let hit = busy.first(where: { $0.start < s + duration && $0.end > s }) {
                s = (((max(hit.end, s + 1)) + step - 1) / step) * step
            } else { return s }
        }
        return nil
    }
}
