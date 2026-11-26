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
        return PanelText.editorDuration(endMinutes - math.minutesSinceMidnight(e.start))
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
        case R.keyLeft: return panelMenus.picking ? move(-1) : false
        case R.keyRight: return panelMenus.picking ? move(1) : false
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
}
