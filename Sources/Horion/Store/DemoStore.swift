import Foundation
import HorionKit

/// In-memory store used for `--demo`, tests, snapshots, the walkthrough and perf runs: the design/mockup-v4 week (`DemoDataV4`).
@MainActor
final class DemoStore: CalendarStore {
    private(set) var accounts: [CalendarAccount]
    let teammates: [Teammate]
    var authorization: StoreAuthorization = .authorized
    let defaultCalendarID: String?
    /// Tests and the `guests-eventkit` snapshot flip this to play EventKit (which cannot add guests).
    var canEditParticipants = true
    var isDemo: Bool { true }
    /// The demo calendars behave like Google: updates can be sent or not, replies are written. Tests flip these to play EventKit.
    var canSendUpdates = true
    var canRespond = true
    /// Every write that chose whether guests hear about it: (event id, "update" or "delete", notify).
    private(set) var notices: [(id: String, kind: String, notify: Bool)] = []
    /// Tests: every write throws (a network error).
    var failWrites = false
    struct WriteFailed: Error {}
    /// Tests flip this to exercise the debounced write path that EventKit uses.
    var coalescesTextEdits = false
    var onChange: (() -> Void)?

    private var events: [CalendarEvent]          // sorted by start
    private var maxDuration: TimeInterval = 0
    private let teamEvents: [String: [CalendarEvent]]
    private let math = DemoDataV4.math
    private(set) var refreshCount = 0

    /// `dense`: 300 more events a week for 120 weeks (the perf run).
    init(dense: Bool = false, authorization: StoreAuthorization = .authorized, fixture: LaunchOptions.Fixture = .v4) {
        self.authorization = authorization
        let v11 = fixture == .v11
        accounts = v11 ? DemoDataV11.accounts : DemoDataV4.accounts
        teammates = v11 ? DemoDataV11.teammates : DemoDataV4.teammates
        defaultCalendarID = v11 ? DemoDataV11.cal("personal") : DemoDataV4.personal
        let t0 = CFAbsoluteTimeGetCurrent()
        events = ((v11 ? DemoDataV11.buildEvents() : DemoDataV4.buildEvents()) + (dense ? DemoDataV4.denseEvents() : [])).sorted { $0.start < $1.start }
        if ProcessInfo.processInfo.environment["HORION_PROF"] != nil { print(String(format: "buildEvents %.0f ms (%d events)", (CFAbsoluteTimeGetCurrent() - t0) * 1000, events.count)) }
        let t1 = CFAbsoluteTimeGetCurrent()
        var byMail: [String: [CalendarEvent]] = [:]
        for e in v11 ? [] : DemoDataV4.teammateEvents() { byMail[e.ownerEmail ?? "", default: []].append(e) }
        teamEvents = byMail
        if ProcessInfo.processInfo.environment["HORION_PROF"] != nil { print(String(format: "teammates %.0f ms", (CFAbsoluteTimeGetCurrent() - t1) * 1000)) }
        recomputeMax()
    }

    /// Snapshots: a calendar becomes read-only (a subscribed calendar), as the fixture has none.
    func makeReadOnly(_ calendarID: String) {
        accounts = accounts.map { a in
            var a = a
            a.calendars = a.calendars.map { c in var c = c; if c.id == calendarID { c.isWritable = false }; return c }
            return a
        }
    }

    private func recomputeMax() { maxDuration = events.reduce(0) { max($0, $1.end.timeIntervalSince($1.start)) } }

    private func lowerBound(_ t: Date) -> Int {
        var lo = 0, hi = events.count
        while lo < hi { let m = (lo + hi) / 2; if events[m].start < t { lo = m + 1 } else { hi = m } }
        return lo
    }

    func requestAccess() async {}
    func refresh() { refreshCount += 1; onChange?() }

    func events(in range: DateInterval) -> [CalendarEvent] {
        var out: [CalendarEvent] = []
        var i = lowerBound(range.start.addingTimeInterval(-maxDuration))
        while i < events.count, events[i].start < range.end {
            if events[i].end > range.start || (events[i].end == events[i].start && events[i].start >= range.start) { out.append(events[i]) }
            i += 1
        }
        return out
    }

    func teammateEvents(_ email: String, in range: DateInterval) -> [CalendarEvent] {
        (teamEvents[email] ?? []).filter { $0.end > range.start && $0.start < range.end }
    }

    func searchCorpus(around date: Date) -> [CalendarEvent] { events }

    func series(of event: CalendarEvent) -> [CalendarEvent] {
        guard let sid = event.seriesID else { return [event] }
        return events.filter { $0.seriesID == sid }
    }

    @discardableResult
    func create(_ event: CalendarEvent) throws -> CalendarEvent {
        insert(event)
        onChange?()
        return event
    }

    /// A new rule (the Repeat menu): the series is made again from its first occurrence, at the edited time of day, a year and a
    /// bit ahead. The edited occurrence keeps its id; "Does not repeat" leaves only it.
    private func reseries(old: CalendarEvent, new event: CalendarEvent, insertingOld: Bool = true) {
        let members = insertingOld ? (old.seriesID.map { sid in events.filter { $0.seriesID == sid } } ?? [old]) : []
        let first = members.min { $0.start < $1.start } ?? old
        let gone = Set(members.map(\.id))
        events.removeAll { gone.contains($0.id) }
        defer {
            events.sort { $0.start != $1.start ? $0.start < $1.start : $0.id < $1.id }
            recomputeMax()
        }
        guard let r = event.recurrence else {
            var e = event
            e.seriesID = nil
            events.append(e)
            return
        }
        let sid = old.seriesID ?? "series.\(old.id)"
        let dur = event.end.timeIntervalSince(event.start)
        let from = event.isAllDay ? math.startOfDay(first.start) : math.date(on: first.start, minutes: math.minutesSinceMidnight(event.start))
        for s in RepeatRules.starts(r, first: min(from, event.start), through: math.addDays(from, 400), math: math) {
            var e = event
            e.seriesID = sid
            e.start = s
            e.end = s.addingTimeInterval(dur)
            e.id = math.isSameDay(s, event.start) ? event.id : "\(sid)@\(Int(s.timeIntervalSince1970))"
            events.append(e)
        }
    }

    private func insert(_ e: CalendarEvent) {
        let i = lowerBound(e.start)
        events.insert(e, at: i)
        maxDuration = max(maxDuration, e.end.timeIntervalSince(e.start))
    }

    @discardableResult
    func update(_ event: CalendarEvent, span: EditSpan) throws -> CalendarEvent {
        if failWrites { throw WriteFailed() }
        guard let idx = events.firstIndex(where: { $0.id == event.id }) else { return event }
        let old = events[idx]
        if old.recurrence != event.recurrence, span == .future, let sid = old.seriesID {
            // this and following: the old series keeps what is before this occurrence, a new series starts with it
            events.removeAll { $0.seriesID == sid && $0.start >= old.start }
            for i in events.indices where events[i].seriesID == sid { events[i].recurrence?.until = math.addDays(math.startOfDay(old.start), -1) }
            var head = event
            head.seriesID = nil
            reseries(old: head, new: head, insertingOld: false)
            onChange?()
            return event
        }
        if old.recurrence != event.recurrence {
            reseries(old: old, new: event)
            onChange?()
            return event
        }
        var targets: [Int] = [idx]
        if span != .this, let sid = old.seriesID {
            targets = events.indices.filter { events[$0].seriesID == sid && (span == .all || events[$0].start >= old.start) }
        }
        let dayDelta = math.daysBetween(old.start, event.start)
        let startMin = math.minutesSinceMidnight(event.start)
        let dur = event.end.timeIntervalSince(event.start)
        for t in targets {
            var e = event
            if events[t].id != event.id {
                e.id = events[t].id
                if !event.isAllDay {
                    let day = math.addDays(events[t].start, dayDelta)
                    e.start = math.date(on: day, minutes: startMin)
                    e.end = e.start.addingTimeInterval(dur)
                } else {
                    e.start = math.addDays(events[t].start, dayDelta)
                    e.end = e.start.addingTimeInterval(dur)
                }
            }
            events[t] = e
        }
        events.sort { $0.start != $1.start ? $0.start < $1.start : $0.id < $1.id }
        recomputeMax()
        onChange?()
        return event
    }

    @discardableResult
    func create(_ event: CalendarEvent, notify: Bool) throws -> CalendarEvent {
        if failWrites { throw WriteFailed() }
        notices.append((event.id, "create", notify))
        // a new repeating event (the draft saved): its occurrences. Undo and tests put single events back through `create(_:)`.
        if event.recurrence != nil && event.seriesID == nil {
            reseries(old: event, new: event, insertingOld: false)
            onChange?()
            return event
        }
        return try create(event)
    }

    @discardableResult
    func update(_ event: CalendarEvent, span: EditSpan, notify: Bool) throws -> CalendarEvent {
        if failWrites { throw WriteFailed() }
        notices.append((event.id, "update", notify))
        return try update(event, span: span)
    }

    func delete(_ event: CalendarEvent, span: EditSpan, notify: Bool) throws {
        if failWrites { throw WriteFailed() }
        notices.append((event.id, "delete", notify))
        try delete(event, span: span)
    }

    func delete(_ event: CalendarEvent, span: EditSpan) throws {
        if failWrites { throw WriteFailed() }
        if span == .this || event.seriesID == nil {
            events.removeAll { $0.id == event.id }
        } else if let sid = event.seriesID {
            events.removeAll { $0.seriesID == sid && (span == .all || $0.start >= event.start) }
        }
        onChange?()
    }
}
