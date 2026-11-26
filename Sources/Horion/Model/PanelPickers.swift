import Foundation
import HorionKit

/// The pickers that drop down from the panel's fields (Notion Calendar's level of function): a time list under the start and end
/// fields, a mini month under the date field. They open when the field takes the keyboard (click or Tab) and the field keeps it: typing still works and moves the list.
/// Up and Down move the list, Return picks the row (once the arrows moved it; before that Return commits what was typed), Esc closes
/// the list and leaves the field focused, Tab closes it and moves on. In the mini month Up and Down move a week; Left and Right move a
/// day once the arrows are in it (before that they move the caret); Page Up and Page Down move a month.
extension AppModel {
    /// The menus that hang under a text field and follow its typing.
    static let fieldPickers: Set<PanelMenu> = [.startTime, .endTime, .datePicker]

    func fieldPicker(_ f: PanelFocus) -> PanelMenu? {
        switch f {
        case .start: .startTime
        case .end: .endTime
        case .date: .datePicker
        default: nil
        }
    }

    /// The field focused: its picker opens on the current value.
    func openFieldPicker(_ f: PanelFocus) {
        guard let m = fieldPicker(f), let e = selectedEvent, editorCanEdit(e) else { return }
        panelMenus.picking = false
        if m == .datePicker {
            guard !e.isAllDay || math.daysBetween(e.start, e.end) <= 1 else { return }
            panelMenus.open = m
            showPickDay(math.startOfDay(e.start))
            return
        }
        guard !e.isAllDay else { return }
        panelMenus.open = m
        panelMenus.highlight = timeKey(TimeSlots.slot(for: currentMinutes(m, e), in: timeChoices(m)))
    }

    /// The field lost the keyboard: its picker closes.
    func closeFieldPicker(_ f: PanelFocus) {
        if let m = fieldPicker(f), panelMenus.open == m { closePanelMenu() }
    }

    // MARK: Times

    func timeChoices(_ m: PanelMenu) -> [Int] {
        guard let e = selectedEvent else { return [] }
        return m == .endTime ? TimeSlots.ends(after: math.minutesSinceMidnight(e.start)) : TimeSlots.starts
    }

    private func currentMinutes(_ m: PanelMenu, _ e: CalendarEvent) -> Int {
        if m == .endTime {
            let end = math.minutesSinceMidnight(e.end)
            return end == 0 && e.end > e.start ? 1440 : end
        }
        return math.minutesSinceMidnight(e.start)
    }

    func timeKey(_ minutes: Int?) -> String? { minutes.map { "time:\($0)" } }

    var highlightedMinutes: Int? {
        guard let h = panelMenus.highlight, h.hasPrefix("time:") else { return nil }
        return Int(h.dropFirst(5))
    }

    /// "3 h 15 min" after an end time in the end list.
    func timeLength(_ endMinutes: Int) -> String? {
        guard let e = selectedEvent else { return nil }
        return PanelText.listLength(endMinutes - math.minutesSinceMidnight(e.start))
    }

    /// A row clicked, or Return on the highlighted one.
    func pickTime(_ m: PanelMenu, _ minutes: Int) {
        switch m {
        case .startTime: setSelectedStart(minutes)
        case .endTime: _ = setSelectedEnd(minutes)
        default: return
        }
        closePanelMenu()
        panelMenus.picking = false
        panelMenus.pickTick += 1
    }

    // MARK: Date

    /// The mini month's day under the keyboard; the month follows it.
    func showPickDay(_ d: Date) {
        panelMenus.pickDay = d
        if panelMenus.pickMonth.map({ !math.isSameMonth($0, d) }) ?? true { panelMenus.pickMonth = math.startOfMonth(d) }
    }

    /// ‹ › in the mini month.
    func stepPickMonth(_ d: Int) {
        let m = math.addMonths(panelMenus.pickMonth ?? math.startOfMonth(selectedEvent?.start ?? now), d)
        panelMenus.pickMonth = math.startOfMonth(m)
    }

    /// A day clicked, or Return on the keyboard's day.
    func pickDate(_ d: Date) {
        setSelectedDate(d)
        closePanelMenu()
        panelMenus.picking = false
        panelMenus.pickTick += 1
    }

    private func handleDatePickerKey(_ k: KeyInput) -> Bool {
        typealias R = ShortcutResolver
        let day = panelMenus.pickDay ?? math.startOfDay(selectedEvent?.start ?? now)
        func move(_ n: Int) -> Bool { showPickDay(math.addDays(day, n)); panelMenus.picking = true; return true }
        switch k.keyCode {
        case R.keyDown: return move(7)
        case R.keyUp: return move(-7)
        // ← → always move days while the mini month is open (user pick after v21); Esc closes it to move the caret
        case R.keyLeft: return move(-1)
        case R.keyRight: return move(1)
        case Self.keyPageUp, Self.keyPageDown:
            showPickDay(math.addMonths(day, k.keyCode == Self.keyPageDown ? 1 : -1))
            panelMenus.picking = true
            return true
        case R.keyReturn, R.keyEnter:
            guard panelMenus.picking else { return false }
            pickDate(day)
            return true
        default: return false
        }
    }

    static let keyPageUp: UInt16 = 116
    static let keyPageDown: UInt16 = 121

    /// The field's text changed: the list follows it to the row of the typed time (the mini month to the typed day).
    func fieldPickerTyped(_ f: PanelFocus, _ text: String) {
        guard let m = fieldPicker(f), panelMenus.open == m else { return }
        panelMenus.picking = false
        if m == .datePicker {
            if let e = selectedEvent, let d = PanelText.parseDay(text, now: now, event: e.start, math: math) { showPickDay(math.startOfDay(d)) }
            return
        }
        if let t = TimeParser.parse(text), let s = TimeSlots.slot(for: t, in: timeChoices(m)) { panelMenus.highlight = timeKey(s) }
    }

    /// Keys while a field's picker is open and its field has the keyboard. True when the key was used.
    func handleFieldPickerKey(_ k: KeyInput, menu m: PanelMenu) -> Bool {
        typealias R = ShortcutResolver
        guard !k.command && !k.control && !k.option else { return false }
        if k.keyCode == R.keyEscape { closePanelMenu(); panelMenus.picking = false; return true }
        if m == .datePicker { return handleDatePickerKey(k) }
        switch k.keyCode {
        case R.keyDown, R.keyUp:
            let d = k.keyCode == R.keyDown ? 1 : -1
            panelMenus.highlight = timeKey(TimeSlots.move(highlightedMinutes, by: d, in: timeChoices(m)))
            panelMenus.picking = true
            return true
        case R.keyReturn, R.keyEnter:
            guard panelMenus.picking, let t = highlightedMinutes else { return false }
            pickTime(m, t)
            return true
        default:
            return false
        }
    }

    // MARK: Time zone

    /// Every zone at the event's start (offsets with daylight saving), searched by `zoneQuery`.
    var zoneChoices: [TimeZoneEntry] {
        guard let e = selectedEvent else { return [] }
        return TimeZoneList.filter(ZoneListCache.list(at: math.startOfDay(e.start)), panelMenus.zoneQuery)
    }

    /// The zone button: the menu opens on the event's zone, the keyboard drives it either way.
    func openZonePicker(byKeyboard: Bool = false) {
        if panelMenus.open == .timeZone && !byKeyboard { closePanelMenu(); return }
        panelMenus.zoneQuery = ""
        panelMenus.stop = .timeZone
        openPanelMenuByKeyboard(.timeZone)
    }

    func zoneQueryChanged(_ q: String) {
        panelMenus.zoneQuery = q
        let keys = zoneChoices.map { "tz:\($0.id)" }
        if let h = panelMenus.highlight, keys.contains(h), q.isEmpty { return }
        panelMenus.highlight = keys.first
    }

    func setSelectedTimeZone(_ id: String) {
        guard TimeZone(identifier: id) != nil else { return }
        updateSelected { $0.timeZoneID = id }
    }

    /// The zone button's text (v21: always the zone): "GMT+2" and "Berlin", also while the event is in the calendar's own zone.
    func zoneLabel(_ e: CalendarEvent) -> (offset: String, city: String) {
        let id = TimeZone(identifier: e.timeZoneID) != nil ? e.timeZoneID : math.timeZone.identifier
        let tz = TimeZone(identifier: id) ?? math.timeZone
        return (TimeZoneList.shortOffset(tz.secondsFromGMT(for: e.start)), TimeZoneList.city(id))
    }
}

// MARK: Repeat

/// The Repeat menu (`PanelMenu.repeats`): the common rules for the event's start ("Weekly on Thu"), then the custom rule in three
/// rows that Left and Right (or their ‹ › buttons) change: every N, the unit, the end. A rule change goes to the whole series.
extension AppModel {
    static let customRepeatKeys = ["rep:every", "rep:unit", "rep:until"]

    var repeatChoices: [PanelMenuChoice] {
        guard let e = selectedEvent else { return [] }
        let until = e.recurrence?.until
        return RepeatChoice.allCases.map { c in
            PanelMenuChoice(key: "rep:\(c.rawValue)") { [weak self] in
                guard let self else { return }
                setSelectedRecurrence(RepeatRules.rule(c, start: e.start, math: math, until: c == .none ? nil : until))
            }
        } + Self.customRepeatKeys.map { PanelMenuChoice(key: $0, run: {}, staysOpen: true) }
    }

    /// The row the menu opens on: the event's rule, or the custom rows.
    func repeatKey(_ e: CalendarEvent) -> String {
        if e.recurrence == nil && e.seriesID != nil { return "rep:every" }
        return RepeatRules.choice(of: e.recurrence, start: e.start, math: math).map { "rep:\($0.rawValue)" } ?? "rep:every"
    }

    func openRepeatMenu(byKeyboard: Bool = false) {
        if panelMenus.open == .repeats && !byKeyboard { closePanelMenu(); return }
        repeatSpan = nil
        panelMenus.stop = .repeats
        openPanelMenuByKeyboard(.repeats)
    }

    /// Left and Right on a custom row (and its buttons): every N, the unit, the end.
    func stepCustomRepeat(_ key: String, by d: Int) {
        guard let e = selectedEvent else { return }
        let r: Recurrence
        switch key {
        case "rep:every": r = RepeatRules.stepInterval(e.recurrence, by: d, start: e.start, math: math)
        case "rep:unit": r = RepeatRules.stepFrequency(e.recurrence, by: d, start: e.start, math: math)
        case "rep:until": r = RepeatRules.stepUntil(e.recurrence, by: d, start: e.start, math: math)
        default: return
        }
        setSelectedRecurrence(r, reopen: key)
        if overlay == nil { panelMenus.highlight = key }
    }

    /// Writes a new rule. The event being created only keeps it. A repeating event with occurrences before this one asks first
    /// (v21 `scope: ask`): All events, or This and following (the series ends the day before and a new one starts here). The
    /// answer holds while the Repeat menu stays open, so the custom rows' ‹ › do not ask at every step. Guests hear about it.
    func setSelectedRecurrence(_ r: Recurrence?, reopen: String? = nil) {
        guard var e = selectedEvent, editorCanEdit(e), e.recurrence != r else { return }
        let before = e
        e.recurrence = r
        if draft?.id == e.id { draft = e; reload(); return }
        flushPendingEdit()
        if before.seriesID != nil, repeatSpan == nil, deleteOffersFollowing(before) {
            closePanelMenu()
            recurringEdit = RecurringEdit(base: before, edited: e, old: nil, notify: nil, rule: true, reopen: reopen)
            spanChoice = .all
            overlay = .editRecurring(e.id)
            return
        }
        saveRecurrence(e, before: before, span: before.seriesID != nil ? (repeatSpan ?? .all) : .this)
    }

    func saveRecurrence(_ e: CalendarEvent, before: CalendarEvent, span: EditSpan) {
        let r = e.recurrence
        let guests = e.attendees.contains { !$0.isMe }
        do {
            let saved = try store.update(e, span: span, notify: guests && store.canSendUpdates(calendarID: e.calendarID))
            storeChanged()
            // the occurrence on screen stays selected when the new rule still has it
            if event(id: e.id) == nil {
                let day = DateInterval(start: math.startOfDay(e.start), end: math.addDays(math.startOfDay(e.start), 1))
                let same = store.events(in: day).first { $0.title == e.title && $0.calendarID == e.calendarID && ($0.seriesID != nil || r == nil) }
                selectedEventID = same?.id ?? saved.id
            }
            if span == .future { repeatSpan = .all }   // the new series starts here: later steps change all of it
        } catch { showToast("Could not save the repeat rule") }
    }

    /// The custom rows' texts: "Every 2", "weeks", "No end" / "Until 26 Feb 2027".
    func customRepeatTexts(_ e: CalendarEvent) -> (every: String, unit: String, until: String) {
        let r = e.recurrence ?? RepeatRules.rule(.weekly, start: e.start, math: math)!
        let unit: String = switch r.frequency { case .daily: "day"; case .weekly: "week"; case .monthly: "month"; case .yearly: "year" }
        return ("Every \(r.interval)", r.interval == 1 ? unit : unit + "s",
                r.until.map { "Until \(PanelText.day($0, fmt)) \(math.year($0))" } ?? "No end")
    }
}

// MARK: Guests

/// The guest field's suggestions by keyboard: Up and Down move a row (the first one is Return's until then), typing starts over.
extension AppModel {
    func guestKey(_ t: Teammate) -> String { "menu:guest:\(t.email)" }

    var highlightedGuest: Teammate? {
        guard panelMenus.open == .guests, let h = panelMenus.highlight else { return nil }
        return guestSuggestions(panelMenus.guestQuery).first { guestKey($0) == h }
    }

    func guestQueryChanged(_ q: String) {
        panelMenus.guestQuery = q
        panelMenus.open = .guests
        panelMenus.highlight = nil
    }

    /// Up and Down in the guest field. True when used.
    func moveGuestHighlight(_ d: Int) -> Bool {
        let list = guestSuggestions(panelMenus.guestQuery)
        guard panelMenus.open == .guests, !list.isEmpty else { return false }
        let i = list.firstIndex { guestKey($0) == panelMenus.highlight }
        let n = i.map { min(max($0 + d, 0), list.count - 1) } ?? (d > 0 ? (list.count > 1 ? 1 : 0) : 0)
        panelMenus.highlight = guestKey(list[n])
        return true
    }

    /// The hint under an EventKit event's guests: Settings → Accounts, where a Google account (or the demo one) can be connected.
    func openAccountsForGuests() {
        services.settingsPage = .accounts
        overlay = .settings
    }
}

/// `TimeZoneList.all` names some 400 zones: made once per day it is asked for.
@MainActor
enum ZoneListCache {
    private static var day: Date?
    private static var cached: [TimeZoneEntry] = []
    static func list(at d: Date) -> [TimeZoneEntry] {
        if day != d { cached = TimeZoneList.all(at: d); day = d }
        return cached
    }
}
