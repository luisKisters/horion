import Foundation

// MARK: - Block placement

public struct Placement: Equatable, Sendable {
    /// A single full-width column (a block with no overlap layout).
    public init(id: String, column: Int, columns: Int, span: Int = 1, over: Bool = false) {
        self.id = id; self.column = column; self.columns = columns; self.span = span; self.over = over
        left = Double(column) / Double(columns); width = Double(span) / Double(columns); order = column
    }
    /// A v4 placement (`OverlapV5`), `order` is its place in the day's drawing order.
    public init(v5 p: V5Placement, order: Int) {
        id = p.id; column = 0; columns = 1; span = 1; over = p.cut
        left = p.left; width = p.width; indent = p.indent; level = p.level; self.order = order; drawEndMinute = p.endMinute
    }
    public var id: String
    public var column: Int
    public var columns: Int
    /// Columns this event reaches across, starting at `column`.
    public var span: Int
    /// Cut: laid against or over another block, drawn with a window-coloured ring so it reads as cut out.
    public var over: Bool
    /// 0...1 of the day column width.
    public var left: Double
    public var width: Double
    /// Extra points from the left (the v5 cascade).
    public var indent: Double = 0
    /// v5 level: 0 for the base, +1 per cascade step, 8 unaccepted, 9 short items.
    public var level: Int = 0
    public var order: Int = 0
    /// Where the block is drawn to when that differs from the event end (a short item spans 22 minutes).
    public var drawEndMinute: Int?
    /// A later block starts on it within `RangeLayoutBuilder.coverMinutes` of its start (mockup-v11 `cut`).
    public var covered = false
    /// Minutes from the start that show: up to the first later block drawn over it (mockup-v14). The text is planned on this part,
    /// so a tall block covered low down still wraps its title and shows its time, and nothing peeks out half hidden. Nil: uncovered.
    public var visibleMinutes: Int?
    /// Paint order: the mockup's `z-index: 1 + min(level, 4)`, then the layout order.
    public var z: Int { min(level, 4) * 1000 + order }
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
    public init(id: String, lane: Int, firstDay: Int, lastDay: Int, clippedLeft: Bool, clippedRight: Bool) {
        self.id = id; self.lane = lane; self.firstDay = firstDay; self.lastDay = lastDay; self.clippedLeft = clippedLeft; self.clippedRight = clippedRight
    }
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
    public init(id: String, event: CalendarEvent, dayIndex: Int, startMinute: Int, endMinute: Int, placement: Placement,
                continuesFromPrevious: Bool = false, continuesToNext: Bool = false) {
        self.id = id; self.event = event; self.dayIndex = dayIndex; self.startMinute = startMinute; self.endMinute = endMinute
        self.placement = placement; self.continuesFromPrevious = continuesFromPrevious; self.continuesToNext = continuesToNext
    }
}

public struct RangeLayout: Sendable {
    public var days: [Date]
    public var timed: [[PlacedEvent]]         // per day, in paint order
    public var allDay: AllDayLayout
    public var allDayEvents: [String: CalendarEvent]
    /// Hour height on screen. The v5 layout is in minutes, so it does not depend on it.
    public var pointsPerHour: Double = 56
    public static let empty = RangeLayout(days: [], timed: [], allDay: .empty, allDayEvents: [:])

    public var timedCount: Int { timed.reduce(0) { $0 + $1.count } }

    /// The same layout for another hour height: nothing to redo, the layout is in minutes.
    public func repacked(pointsPerHour pph: Double) -> RangeLayout {
        var r = self
        r.pointsPerHour = pph
        return r
    }

}

public enum RangeLayoutBuilder {
    /// Day index (relative to `days`) containing `t`, by binary search over the day starts: DST safe and much cheaper than Calendar.
    public static func dayIndex(_ t: Date, starts: [Date]) -> Int {
        var lo = 0, hi = starts.count
        while lo < hi { let m = (lo + hi) / 2; if starts[m] <= t { lo = m + 1 } else { hi = m } }
        return lo - 1      // -1 before the range, starts.count - 1 at/after the last start
    }

    /// The v5 input for one day segment. Short or not follows the event's real length.
    public static func item(_ p: PlacedEvent, id: String) -> V5Item {
        let e = p.event
        let short = !e.isAllDay && e.end.timeIntervalSince(e.start) <= Double(OverlapV5.shortLimit) * 60
        return V5Item(id: id, startMinute: p.startMinute, endMinute: p.endMinute, isShort: short, isUnaccepted: e.isUnaccepted)
    }

    /// Lays out one day with `OverlapV11` (the v11 cascade; crowded spots side by side) and sorts it into paint order.
    /// Every event shows: nothing is folded into "+N" (removed in mockup-v14).
    /// `width`: the day column in points (inside its create strip).
    public static func packDay(_ day: [PlacedEvent], width: Double = OverlapV11.defaultWidth) -> [PlacedEvent] {
        var placed = day
        let placements = OverlapV11.layout(placed.indices.map { item(placed[$0], id: String($0)) }, width: width)
        for (k, p) in placements.enumerated() { if let i = Int(p.id) { placed[i].placement = Placement(v5: p, order: k) } }
        markCovered(&placed, width: width)
        // Sort small integer keys, not the (large) PlacedEvent values.
        let keys = placed.map { $0.placement.z }
        let order = (0..<placed.count).sorted { keys[$0] != keys[$1] ? keys[$0] < keys[$1] : $0 < $1 }
        return order.map { placed[$0] }
    }

    /// A block covered by a later one within this many minutes of its start keeps one line (mockup-v11 `cascade`: `c.s - it.s < 40`).
    public static let coverMinutes = 40

    /// Sets `placement.covered` and `visibleMinutes` on the visible blocks: in start order (the longer first), the first later block
    /// that starts before this one ends and is drawn over it (their columns overlap) covers it from its start (mockup-v11 app.js
    /// `cascade`, the `cut` pass; mockup-v14 adds the column check, so a block beside it does not count).
    /// Only a block over its title counts: one tucked in on the right of it (`OverlapV11` rule 3) leaves the title and time readable.
    static func markCovered(_ placed: inout [PlacedEvent], width: Double = OverlapV11.defaultWidth) {
        let title = (OverlapV11.titleWidth(max(width, 1)) + OverlapV11.gap) / max(width, 1)
        let vis = Array(placed.indices)
        func end(_ i: Int) -> Int { max(placed[i].endMinute, placed[i].placement.drawEndMinute ?? 0) }
        let order = vis.sorted {
            let a = placed[$0], b = placed[$1]
            if a.startMinute != b.startMinute { return a.startMinute < b.startMinute }
            if end($0) - a.startMinute != end($1) - b.startMinute { return end($0) - a.startMinute > end($1) - b.startMinute }
            return $0 < $1
        }
        func across(_ a: Int, _ b: Int) -> Bool {
            let pa = placed[a].placement, pb = placed[b].placement
            return pb.left < pa.left + min(pa.width, title) - 0.001 && pa.left < pb.left + pb.width - 0.001
        }
        for (k, i) in order.enumerated() {
            placed[i].placement.covered = false
            placed[i].placement.visibleMinutes = nil
            if let j = order[(k + 1)...].first(where: { placed[$0].startMinute < end(i) && across(i, $0) }) {
                let shown = placed[j].startMinute - placed[i].startMinute
                placed[i].placement.covered = shown < coverMinutes
                placed[i].placement.visibleMinutes = shown
            }
        }
    }

    /// A timed event at least 24 h long. It goes to the all-day lane.
    public static func isMultiDay(_ e: CalendarEvent) -> Bool { !e.isAllDay && e.end.timeIntervalSince(e.start) >= 86_400 }

    public static func build(events: [CalendarEvent], days: [Date], math: CalendarMath, pointsPerHour: Double = 56,
                             columnWidth: Double = OverlapV11.defaultWidth) -> RangeLayout {
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
            // A timed event of 24 h or more is a multi-day span: it shows in the all-day lane, not as columns in the grid.
            // Shorter overnight events stay in the grid, split at midnight.
            if isMultiDay(ev) {
                let a = math.daysBetween(days[0], ev.start)
                let b = math.daysBetween(days[0], endInstant)
                guard b >= 0, a < dayCount else { continue }
                allDayItems.append(AllDayItem(id: ev.id, firstDay: a, lastDay: b))
                allDayMap[ev.id] = ev
                continue
            }
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
            let placed = perDaySpans[d].map { sp in
                PlacedEvent(id: "\(sp.event.id)|\(d)", event: sp.event, dayIndex: d, startMinute: sp.s, endMinute: sp.e,
                            placement: Placement(id: "", column: 0, columns: 1), continuesFromPrevious: sp.from, continuesToNext: sp.to)
            }
            timed.append(packDay(placed, width: columnWidth))
        }
        return RangeLayout(days: days, timed: timed, allDay: AllDayPacker.pack(allDayItems, dayCount: dayCount), allDayEvents: allDayMap,
                           pointsPerHour: pointsPerHour)
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
