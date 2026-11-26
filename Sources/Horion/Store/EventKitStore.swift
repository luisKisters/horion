import Foundation
import EventKit
import HorionKit

/// Real calendars via EventKit. Google accounts added in System Settings > Internet Accounts (CalDAV), iCloud and
/// "On My Mac" all show up here. This file only copies fields between EventKit and HorionKit values; grouping,
/// colors and status decisions live in `EventKitMapping` (tested).
@MainActor
final class EventKitStore: CalendarStore {
    private let store = EKEventStore()
    private let math: CalendarMath
    private(set) var accounts: [CalendarAccount] = []
    private(set) var teammates: [Teammate] = []
    private var attendeeIndex: [String: [CalendarEvent]] = [:]
    var onChange: (() -> Void)?
    let canEditParticipants = false
    var coalescesTextEdits: Bool { true }
    var searchCorpusIsAsync: Bool { true }
    private var cache: [String: EKEvent] = [:]
    private var observer: NSObjectProtocol?
    /// A delete that failed in the background (the events are back on the grid).
    var onError: ((String) -> Void)?
    private let writer = Writer()
    /// Deletes saved on `writer`, newest last: while `pending` their events stay hidden here, and undo puts `events` back at once.
    private var deletes: [(token: UUID, record: DeleteRecord)] = []
    /// Events an undo put back, shown until EventKit has saved them.
    private var restoring: [UUID: [CalendarEvent]] = [:]
    /// Background saves still running (tests and tours wait for none).
    private(set) var inFlight = 0

    var authorization: StoreAuthorization {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .authorized
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    var defaultCalendarID: String? { authorization == .authorized ? store.defaultCalendarForNewEvents?.calendarIdentifier : nil }

    init(math: CalendarMath = .system) {
        self.math = math
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reloadCalendars()
                self?.onChange?()
            }
        }
        if authorization == .authorized { reloadCalendars() }
    }

    func requestAccess() async {
        _ = try? await store.requestFullAccessToEvents()
        reloadCalendars()
        onChange?()
    }

    func refresh() {
        store.refreshSourcesIfNecessary()
        reloadCalendars()
        onChange?()
    }

    // MARK: Calendars

    private func reloadCalendars() {
        guard authorization == .authorized else { accounts = []; return }
        let cals = store.calendars(for: .event)
        var rawSources: [String: RawSource] = [:]
        var rawCals: [RawCalendar] = []
        for c in cals {
            guard let s = c.source else { continue }
            rawSources[s.sourceIdentifier] = RawSource(id: s.sourceIdentifier, title: s.title, type: Self.map(s.sourceType))
            let rgb = (c.color ?? .gray).usingColorSpace(.sRGB)
            rawCals.append(RawCalendar(id: c.calendarIdentifier, sourceID: s.sourceIdentifier, title: c.title, type: Self.map(c.type),
                                       red: Double(rgb?.redComponent ?? 0.5), green: Double(rgb?.greenComponent ?? 0.5), blue: Double(rgb?.blueComponent ?? 0.5),
                                       allowsContentModifications: c.allowsContentModifications))
        }
        accounts = EventKitMapping.accounts(sources: Array(rawSources.values), calendars: rawCals, defaultCalendarID: store.defaultCalendarForNewEvents?.calendarIdentifier)
    }

    nonisolated static func map(_ t: EKSourceType) -> RawSourceType {
        switch t {
        case .local: .local
        case .exchange: .exchange
        case .calDAV: .calDAV
        case .mobileMe: .mobileMe
        case .subscribed: .subscribed
        case .birthdays: .birthdays
        @unknown default: .local
        }
    }
    nonisolated static func map(_ t: EKCalendarType) -> RawCalendarType {
        switch t {
        case .local: .local
        case .calDAV: .calDAV
        case .exchange: .exchange
        case .subscription: .subscription
        case .birthday: .birthday
        @unknown default: .local
        }
    }
    nonisolated static func raw(_ a: EKAlarm) -> RawAlarm { RawAlarm(relativeOffset: a.relativeOffset, isAbsolute: a.absoluteDate != nil) }

    nonisolated static func raw(_ p: EKParticipant) -> RawParticipant {
        let mail = p.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
        let role: RawParticipantRole = switch p.participantRole {
        case .required: .required
        case .optional: .optional
        case .chair: .chair
        case .nonParticipant: .nonParticipant
        default: .unknown
        }
        let kind: RawParticipantKind = switch p.participantType {
        case .person: .person
        case .room: .room
        case .resource: .resource
        case .group: .group
        default: .unknown
        }
        return RawParticipant(name: p.name, email: mail.contains("@") ? mail : nil, isCurrentUser: p.isCurrentUser, role: role,
                              status: map(p.participantStatus), kind: kind)
    }

    nonisolated static func map(_ s: EKParticipantStatus) -> RawParticipantStatus {
        switch s {
        case .unknown: .unknown
        case .pending: .pending
        case .accepted: .accepted
        case .declined: .declined
        case .tentative: .tentative
        case .delegated: .delegated
        case .completed: .completed
        case .inProcess: .inProcess
        @unknown default: .unknown
        }
    }

    // MARK: Reading

    func events(in range: DateInterval) -> [CalendarEvent] {
        guard authorization == .authorized else { return [] }
        let p = store.predicateForEvents(withStart: range.start, end: range.end, calendars: nil)
        return adjusted(store.events(matching: p).map(convert), in: range)
    }

    /// What EventKit returned, minus deletes still saving, plus events an undo is putting back.
    private func adjusted(_ evs: [CalendarEvent], in range: DateInterval?) -> [CalendarEvent] {
        guard deletes.contains(where: \.record.pending) || !restoring.isEmpty else { return evs }
        var out = evs.filter { !isHidden($0) }
        guard !restoring.isEmpty else { return out }
        var ids = Set(out.map(\.id))
        for e in restoring.values.joined() where !ids.contains(e.id) {
            if let r = range, !(e.end > r.start && e.start < r.end || (e.start == e.end && e.start >= r.start && e.start < r.end)) { continue }
            out.append(e); ids.insert(e.id)
        }
        return out.sorted { $0.start < $1.start }
    }

    private func isHidden(_ e: CalendarEvent) -> Bool {
        deletes.contains { $0.record.pending && $0.record.covers(e) }
    }

    func teammateEvents(_ email: String, in range: DateInterval) -> [CalendarEvent] {
        events(in: range).filter { e in e.attendees.contains { $0.email.lowercased() == email.lowercased() } }
    }

    func searchCorpus(around date: Date) -> [CalendarEvent] {
        let r = DateInterval(start: math.addDays(date, -365), end: math.addDays(date, 365))
        let evs = events(in: r)
        rebuildTeammates(from: evs)
        return evs
    }

    /// A year each way can be thousands of occurrences: fetch and convert them on a background thread with a private
    /// EKEventStore (the identifiers match the main store's, so search results still resolve to editable events).
    func loadSearchCorpus(around date: Date) async -> [CalendarEvent] {
        guard authorization == .authorized else { return [] }
        let math = self.math
        let range = DateInterval(start: math.addDays(date, -365), end: math.addDays(date, 365))
        let evs = await Task.detached(priority: .userInitiated) { () -> [CalendarEvent] in
            let bg = EKEventStore()
            let p = bg.predicateForEvents(withStart: range.start, end: range.end, calendars: nil)
            return bg.events(matching: p).map { Self.makeEvent($0, math: math) }
        }.value
        rebuildTeammates(from: evs)
        return adjusted(evs, in: nil)
    }

    private func rebuildTeammates(from evs: [CalendarEvent]) {
        var seen: [String: Teammate] = [:]
        for e in evs { for a in e.attendees where !a.isMe {
            let mail = a.email
            if !mail.isEmpty, seen[mail] == nil { seen[mail] = Teammate(name: a.label, email: mail) }
        } }
        teammates = seen.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// From the rule alone: `series(of:)` would load two years of events first (about a second on a full calendar).
    /// `seriesID` is only set when the event has recurrence rules.
    func repeats(_ event: CalendarEvent) -> Bool {
        guard event.seriesID != nil else { return false }
        return cache[event.id]?.recurrenceRules?.first?.recurrenceEnd?.occurrenceCount != 1
    }

    func series(of event: CalendarEvent) -> [CalendarEvent] {
        guard let sid = event.seriesID else { return [event] }
        guard authorization == .authorized else { return [] }
        // Only the event's own calendar: two years of every calendar took about a second.
        let cals = store.calendar(withIdentifier: event.calendarID).map { [$0] }
        let p = store.predicateForEvents(withStart: math.addDays(event.start, -365), end: math.addDays(event.start, 365), calendars: cals)
        return adjusted(store.events(matching: p).map(convert).filter { $0.seriesID == sid }, in: nil)
    }

    /// Looks only a couple of rule periods either side, on the event's own calendar, before falling back to a year.
    func hasOccurrencesAround(_ event: CalendarEvent) -> Bool {
        guard let sid = event.seriesID, authorization == .authorized, let ek = cache[event.id],
              let rule = ek.recurrenceRules?.first else { return false }
        let cals = store.calendar(withIdentifier: event.calendarID).map { [$0] }
        let unit: Double = switch rule.frequency { case .daily: 1; case .weekly: 7; case .monthly: 31; case .yearly: 366; @unknown default: 31 }
        let near = TimeInterval(86_400 * (unit * Double(max(rule.interval, 1)) * 2 + 1))
        func found(_ a: Date, _ b: Date) -> Bool {
            guard a < b else { return false }
            let p = store.predicateForEvents(withStart: a, end: b, calendars: cals)
            return store.events(matching: p).contains { ($0.eventIdentifier ?? $0.calendarItemIdentifier) == sid && $0.startDate != ek.startDate }
        }
        let s = ek.startDate ?? event.start
        let ruleEnd = rule.recurrenceEnd?.endDate ?? .distantFuture
        let before = found(s.addingTimeInterval(-near), s) || found(s.addingTimeInterval(-365 * 86_400), s.addingTimeInterval(-near))
        guard before else { return false }
        let after = s.addingTimeInterval(1)
        return found(after, min(s.addingTimeInterval(near), ruleEnd.addingTimeInterval(86_400)))
            || (ruleEnd > s.addingTimeInterval(near) && found(s.addingTimeInterval(near), min(s.addingTimeInterval(365 * 86_400), ruleEnd.addingTimeInterval(86_400))))
    }

    private func convert(_ ev: EKEvent) -> CalendarEvent {
        let out = Self.makeEvent(ev, math: math)
        cache[out.id] = ev
        return out
    }

    nonisolated static func makeEvent(_ ev: EKEvent, math: CalendarMath) -> CalendarEvent {
        let baseID = ev.eventIdentifier ?? ev.calendarItemIdentifier
        let id = "\(baseID)@\(Int(ev.startDate.timeIntervalSince1970))"
        let attendees = EventKitMapping.attendees((ev.attendees ?? []).map(Self.raw), organizer: ev.organizer.map(Self.raw))
        let mine = (ev.attendees ?? []).first(where: { $0.isCurrentUser }).map { Self.map($0.participantStatus) }
        let status = EventKitMapping.responseStatus(myStatus: mine, iAmOrganizer: ev.organizer?.isCurrentUser == true,
                                                    eventTentative: ev.status == .tentative, eventCanceled: ev.status == .canceled)
        var start = ev.startDate ?? Date(), end = ev.endDate ?? start
        if ev.isAllDay {
            start = math.startOfDay(start)
            end = math.addDays(math.startOfDay(end.addingTimeInterval(-1)), 1)
            if end <= start { end = math.addDays(start, 1) }
        }
        let cal = ev.calendar
        var e = CalendarEvent(
            id: id, seriesID: ev.hasRecurrenceRules ? baseID : nil, calendarID: cal?.calendarIdentifier ?? "",
            title: ev.title ?? "", start: start, end: end, isAllDay: ev.isAllDay,
            status: status,
            location: ev.location ?? "", notes: ev.notes ?? "", recurrence: ev.recurrenceRules?.first.flatMap(Self.convert),
            attendees: attendees, conferencing: ev.url?.absoluteString ?? "",
            reminders: EventKitMapping.reminders(alarms: (ev.alarms ?? []).map(Self.raw)),
            availability: ev.availability == .free ? .free : .busy, visibility: .standard,
            timeZoneID: ev.timeZone?.identifier ?? math.timeZone.identifier)
        e.externalID = ev.calendarItemExternalIdentifier
        return e
    }

    nonisolated static func convert(_ r: EKRecurrenceRule) -> Recurrence {
        let f: Recurrence.Frequency
        switch r.frequency { case .daily: f = .daily; case .weekly: f = .weekly; case .monthly: f = .monthly; case .yearly: f = .yearly; @unknown default: f = .weekly }
        return Recurrence(frequency: f, interval: r.interval, weekdays: (r.daysOfTheWeek ?? []).map { $0.dayOfTheWeek.rawValue }, until: r.recurrenceEnd?.endDate)
    }

    // MARK: Writing

    @discardableResult
    func create(_ event: CalendarEvent) throws -> CalendarEvent {
        let ek = EKEvent(eventStore: store)
        ek.calendar = store.calendar(withIdentifier: event.calendarID) ?? store.defaultCalendarForNewEvents
        apply(event, to: ek)
        try store.save(ek, span: .thisEvent, commit: true)
        return convert(ek)
    }

    @discardableResult
    func update(_ event: CalendarEvent, span: EditSpan) throws -> CalendarEvent {
        guard let ek = cache[event.id] else { return event }
        if span == .all, let master = ek.eventIdentifier.flatMap({ store.event(withIdentifier: $0) }) {
            var shifted = event
            let delta = event.start.timeIntervalSince(ek.startDate)
            shifted.start = master.startDate.addingTimeInterval(delta)
            shifted.end = shifted.start.addingTimeInterval(event.end.timeIntervalSince(event.start))
            apply(shifted, to: master)
            try store.save(master, span: .futureEvents, commit: true)
            return convert(master)
        }
        apply(event, to: ek)
        try store.save(ek, span: span == .this ? .thisEvent : .futureEvents, commit: true)
        return convert(ek)
    }

    /// The events leave the grid at once; EventKit removes them on `writer`. A failure brings them back with a toast.
    func delete(_ event: CalendarEvent, span: EditSpan) throws {
        guard let ek = cache[event.id] else { return }
        guard let ident = ek.eventIdentifier, let start = ek.startDate, let end = ek.endDate else {
            try store.remove(ek, span: .thisEvent, commit: true); cache[event.id] = nil; return
        }
        let token = UUID()
        var record = DeleteRecord(id: event.id, seriesID: event.seriesID, span: span, from: event.start, identifier: ident, events: [event])
        if span != .this, let sid = event.seriesID {
            // the occurrences already loaded, for the grid and for an instant undo
            record.events = cache.values.filter { ($0.eventIdentifier ?? $0.calendarItemIdentifier) == sid }
                .map { Self.makeEvent($0, math: math) }.filter(record.covers)
        }
        deletes.append((token, record))
        if deletes.count > 100 { deletes.removeFirst(deletes.count - 100) }
        for e in record.events { cache[e.id] = nil }
        let target = Writer.Target(identifier: ident, start: start, end: end, calendarID: event.calendarID)
        let title = event.title
        inFlight += 1
        writer.queue.async { [writer] in
            let ok = writer.delete(target, span: span, token: token)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.inFlight -= 1
                    if let i = self.deletes.firstIndex(where: { $0.token == token }) {
                        self.deletes[i].record.pending = false
                        if !ok { self.deletes.remove(at: i) }
                    }
                    if !ok { self.onError?("Could not delete \u{201C}\(title.isEmpty ? "(No title)" : title)\u{201D}") }
                    self.onChange?()
                }
            }
        }
        onChange?()
    }

    func restoresDeletedSeries(calendarID: String) -> Bool { true }

    /// Undo of "All events" or "This and following": the occurrences show again at once, and the series gets back its rule
    /// ("This and following") or is made again from the old series ("All events"; changed single occurrences come back as the rule has them).
    func restoreDeletedSeries(_ event: CalendarEvent) {
        guard let i = deletes.lastIndex(where: { $0.record.id == event.id && $0.record.span != .this }) else { return }
        let (token, record) = deletes.remove(at: i)
        restoring[token] = record.events
        let ident = record.identifier
        inFlight += 1
        writer.queue.async { [writer] in
            let ok = writer.restore(token, identifier: ident)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.inFlight -= 1
                    self.restoring[token] = nil
                    if !ok { self.onError?("Could not undo") }
                    self.onChange?()
                }
            }
        }
        onChange?()
    }

    private func apply(_ e: CalendarEvent, to ek: EKEvent) {
        ek.title = e.title
        ek.location = e.location.isEmpty ? nil : e.location
        ek.notes = e.notes.isEmpty ? nil : e.notes
        ek.isAllDay = e.isAllDay
        ek.startDate = e.start
        ek.endDate = e.isAllDay ? e.end.addingTimeInterval(-1) : e.end
        ek.availability = e.availability == .free ? .free : .busy
        ek.url = e.conferencing.isEmpty ? nil : URL(string: e.conferencing)
        if e.isAllDay { ek.timeZone = nil }      // all-day events are floating dates
        else if let tz = TimeZone(identifier: e.timeZoneID) { ek.timeZone = tz }
        if let cal = store.calendar(withIdentifier: e.calendarID), cal.allowsContentModifications, ek.calendar?.calendarIdentifier != cal.calendarIdentifier { ek.calendar = cal }
        // Only reminder alarms change, and only when the reminders did (absolute and after-start alarms stay).
        let alarms = ek.alarms ?? []
        if let change = EventKitMapping.alarmChanges(existing: alarms.map(Self.raw), reminders: e.reminders) {
            for i in change.remove { ek.removeAlarm(alarms[i]) }
            for off in change.add { ek.addAlarm(EKAlarm(relativeOffset: off)) }
        }
    }
}

/// One delete the grid already shows. `covers`: the occurrences it takes away.
private struct DeleteRecord {
    let id: String
    let seriesID: String?
    let span: EditSpan
    let from: Date
    let identifier: String
    var events: [CalendarEvent]
    var pending = true

    func covers(_ e: CalendarEvent) -> Bool {
        switch span {
        case .this: e.id == id
        case .future: seriesID != nil && e.seriesID == seriesID && e.start >= from
        case .all: seriesID != nil && e.seriesID == seriesID
        }
    }
}

/// A second `EKEventStore` on its own serial queue: deletes and their undos save there in order, off the main thread.
/// Everything below runs on `queue` only.
private final class Writer: @unchecked Sendable {
    let queue = DispatchQueue(label: "horion.eventkit.writer", qos: .userInitiated)
    private lazy var store = EKEventStore()
    /// The series as it was before a delete, for its undo.
    private var snapshots: [UUID: SeriesSnapshot] = [:]

    struct Target: Sendable { let identifier: String; let start: Date; let end: Date; let calendarID: String }

    struct SeriesSnapshot {
        let title: String?, location: String?, notes: String?, url: URL?
        let isAllDay: Bool, start: Date, end: Date, timeZone: TimeZone?
        let availability: EKEventAvailability, calendarID: String?
        let alarms: [EKAlarm], rules: [EKRecurrenceRule]

        init(_ e: EKEvent) {
            title = e.title; location = e.location; notes = e.notes; url = e.url
            isAllDay = e.isAllDay; start = e.startDate; end = e.endDate; timeZone = e.timeZone
            availability = e.availability; calendarID = e.calendar?.calendarIdentifier
            alarms = (e.alarms ?? []).compactMap { $0.copy() as? EKAlarm }
            rules = (e.recurrenceRules ?? []).compactMap { $0.copy() as? EKRecurrenceRule }
        }

        func make(in store: EKEventStore) -> EKEvent? {
            guard let cal = calendarID.flatMap({ store.calendar(withIdentifier: $0) }) else { return nil }
            let e = EKEvent(eventStore: store)
            e.calendar = cal
            e.title = title; e.location = location; e.notes = notes; e.url = url
            e.isAllDay = isAllDay; e.startDate = start; e.endDate = end; e.timeZone = timeZone
            e.availability = availability
            e.alarms = alarms.compactMap { $0.copy() as? EKAlarm }
            e.recurrenceRules = rules.compactMap { $0.copy() as? EKRecurrenceRule }
            return e
        }
    }

    private func occurrence(_ t: Target) -> EKEvent? {
        let cals = store.calendar(withIdentifier: t.calendarID).map { [$0] }
        let p = store.predicateForEvents(withStart: t.start.addingTimeInterval(-1), end: max(t.end, t.start).addingTimeInterval(1), calendars: cals)
        return store.events(matching: p).first { $0.eventIdentifier == t.identifier && $0.startDate == t.start }
            ?? store.event(withIdentifier: t.identifier).flatMap { $0.hasRecurrenceRules ? nil : $0 }
    }

    /// Already gone counts as done.
    func delete(_ t: Target, span: EditSpan, token: UUID) -> Bool {
        do {
            switch span {
            case .this:
                guard let ev = occurrence(t) else { return true }
                try store.remove(ev, span: .thisEvent, commit: true)
            case .future, .all:
                guard let first = store.event(withIdentifier: t.identifier) else { return true }
                snapshots[token] = SeriesSnapshot(first)
                if span == .all { try store.remove(first, span: .futureEvents, commit: true) }
                else if let ev = occurrence(t) { try store.remove(ev, span: .futureEvents, commit: true) }
            }
            return true
        } catch {
            snapshots[token] = nil
            store.reset()
            return false
        }
    }

    /// The series still there (it was cut short): its old rule again. Gone: made again from the snapshot.
    func restore(_ token: UUID, identifier: String) -> Bool {
        guard let snap = snapshots.removeValue(forKey: token) else { return true }
        do {
            if let first = store.event(withIdentifier: identifier) {
                first.recurrenceRules = snap.rules.compactMap { $0.copy() as? EKRecurrenceRule }
                try store.save(first, span: .futureEvents, commit: true)
            } else if let e = snap.make(in: store) {
                try store.save(e, span: .futureEvents, commit: true)
            } else { return false }
            return true
        } catch {
            store.reset()
            return false
        }
    }
}
