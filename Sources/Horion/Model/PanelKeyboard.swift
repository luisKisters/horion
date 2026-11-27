import Foundation
import HorionKit

/// The event panel by keyboard (design/mockup-v20 round 1, "Flat Tab"): Tab and Shift-Tab go through every field, switch, button
/// and menu, top to bottom, and wrap. Space or Return uses the stop (flips All day, opens a menu); Down opens a menu too. In a
/// menu: Up and Down move, Return or Space picks, Esc closes. Option shows a letter on each stop; Option + the letter jumps there
/// (outside a text field only: there Option types characters, @ on a German keyboard is Option-L).
extension PanelFocus {
    var stop: PanelStop {
        switch self {
        case .title: .title
        case .date: .date
        case .start: .start
        case .end: .end
        case .place: .place
        case .guest: .guest
        case .video: .link
        case .notes: .notes
        }
    }
}

extension PanelStop {
    var focus: PanelFocus? {
        switch self {
        case .title: .title
        case .date: .date
        case .start: .start
        case .end: .end
        case .place: .place
        case .guest: .guest
        case .link: .video
        case .notes: .notes
        default: nil
        }
    }
}

/// One row a menu's keyboard can pick: the `PopItem` key it highlights and what picking it does.
struct PanelMenuChoice {
    let key: String
    let run: () -> Void
    /// The menu stays open after the pick (reminders: several can be on).
    var staysOpen = false
}

extension AppModel {
    /// The panel's stops for the open event.
    func panelStopContext(_ e: CalendarEvent) -> PanelStopContext {
        let canEdit = editorCanEdit(e)
        let rows = EditorRows.rows(editorContext(e))
        let days = e.isAllDay ? max(1, math.daysBetween(e.start, e.end)) : 1
        let link = e.conferencing.trimmingCharacters(in: .whitespacesAndNewlines)
        let gone = panelState.unsent[e.id].flatMap { CallLink.parse($0.base) }
        // the same cases, in the same order, as `PanelCallRow`
        let call: PanelStopContext.Call =
            panelState.newMeet.contains(e.id) ? .none
            : CallLink.parse(e) != nil ? (canEdit ? .linkAndJoin : .joinOnly)
            : !link.isEmpty ? (canEdit ? .link : .none)
            : gone != nil ? .none
            : panelMenus.pastingLink ? .link
            : canEdit ? .add : .none
        let canAddGuests = canEdit && store.canEditParticipants(calendarID: e.calendarID)
        return PanelStopContext(canEdit: canEdit, writable: isWritable(e), dateEditable: canEdit && days == 1, isAllDay: e.isAllDay,
                                going: rows.contains(.going) && canRespond(e) && !e.iAmOrganizer,
                                canAddGuests: canAddGuests, guestsCard: canEdit && !canAddGuests, call: call, reminders: e.reminders)
    }

    var panelStops: [PanelStop] { selectedEvent.map { PanelTabOrder.stops(panelStopContext($0)) } ?? [] }

    /// The event panel shows an event the keyboard can move through.
    var panelTakesKeys: Bool { overlay == nil && rightColumnVisible && selectedEvent != nil && !chromeState.searchFocused }

    /// Moves the keyboard to a stop: a text field takes the keyboard, any other stop shows the focus ring.
    func focusPanelStop(_ s: PanelStop) {
        if let m = panelMenus.open, Self.keyboardMenus.contains(m) || Self.fieldPickers.contains(m) { closePanelMenu() }
        panelMenus.stop = s
        if let f = s.focus { focusEditorField(f) } else { blurTick += 1 }
    }

    /// Tab (1) and Shift-Tab (-1); also Return in a one-line field ("saves, moves on").
    func movePanelStop(_ d: Int) {
        let list = panelStops
        let current = panelMenus.stop.flatMap { list.contains($0) ? $0 : nil }
        guard let next = PanelTabOrder.step(from: current, in: list, by: d) else { return }
        focusPanelStop(next)
    }

    /// The editor's text field focus changed (`PanelDetailView`).
    func panelFieldFocusChanged(_ f: PanelFocus?) {
        if let f {
            panelMenus.stop = f.stop
            openFieldPicker(f)
            return
        }
        // left the field (Esc, a click elsewhere); a move to a switch or menu has set its stop already
        if panelMenus.stop?.isText == true { panelMenus.stop = nil }
    }

    /// The menus the keyboard drives (the guest and place lists follow their fields' typing).
    static let keyboardMenus: Set<PanelMenu> = [.calendar, .reminders, .call, .availability, .visibility, .timeZone, .repeats]

    func panelMenuChoices(_ m: PanelMenu) -> [PanelMenuChoice] {
        guard selectedEvent != nil else { return [] }
        switch m {
        case .calendar:
            return store.accounts.flatMap { $0.calendars.filter(\.isWritable) }.map { c in
                PanelMenuChoice(key: "menu:cal:\(c.id)") { [weak self] in self?.setSelectedCalendar(c.id) }
            }
        case .reminders:
            return Reminders.choices.map { r in PanelMenuChoice(key: "menu:rem\(r)", run: { [weak self] in self?.toggleReminder(r) }, staysOpen: true) }
        case .call:
            var c: [PanelMenuChoice] = []
            if canInventVideoLink { c.append(PanelMenuChoice(key: "menu:meet") { [weak self] in self?.addMeet() }) }
            c.append(PanelMenuChoice(key: "menu:paste") { [weak self] in self?.startPastingLink() })
            return c
        case .availability:
            return Availability.allCases.map { a in PanelMenuChoice(key: "menu:avail:\(a.rawValue)") { [weak self] in self?.updateSelected { $0.availability = a } } }
        case .visibility:
            return EventVisibility.allCases.map { v in PanelMenuChoice(key: "menu:vis:\(v.rawValue)") { [weak self] in self?.updateSelected { $0.visibility = v } } }
        case .repeats:
            return repeatChoices
        case .timeZone:
            return zoneChoices.map { z in PanelMenuChoice(key: "tz:\(z.id)") { [weak self] in self?.setSelectedTimeZone(z.id) } }
        default:
            return []
        }
    }

    /// The row a menu opened by keyboard starts on: the current value, or the first row.
    func panelMenuStartKey(_ m: PanelMenu) -> String? {
        guard let e = selectedEvent else { return nil }
        let keys = panelMenuChoices(m).map(\.key)
        let current: String? = switch m {
        case .calendar: "menu:cal:\(e.calendarID)"
        case .availability: "menu:avail:\(e.availability.rawValue)"
        case .visibility: "menu:vis:\(e.visibility.rawValue)"
        case .reminders: e.reminders.first.map { "menu:rem\($0)" }
        case .timeZone: "tz:\(e.timeZoneID)"
        case .repeats: repeatKey(e)
        default: nil
        }
        return current.flatMap { keys.contains($0) ? $0 : nil } ?? keys.first
    }

    /// Space, Return (or Down for a menu) on a stop that is not a text field.
    func activatePanelStop(_ s: PanelStop) {
        guard let e = selectedEvent else { return }
        switch s {
        case .allDay: setSelectedAllDay(!e.isAllDay)
        case .timeZone: openZonePicker(byKeyboard: true)
        case .repeats: openRepeatMenu(byKeyboard: true)
        case .guestsCard: openAccountsForGuests()
        case .join: joinCall(e)
        case .addCall: openPanelMenuByKeyboard(.call)
        case .calendar: openPanelMenuByKeyboard(.calendar)
        case .busy: openPanelMenuByKeyboard(.availability)
        case .visibility: openPanelMenuByKeyboard(.visibility)
        case .reminder, .addReminder: openPanelMenuByKeyboard(.reminders)
        case .going: break
        default: if let f = s.focus { focusEditorField(f) }
        }
    }

    func openPanelMenuByKeyboard(_ m: PanelMenu) {
        panelMenus.open = m
        panelMenus.highlight = panelMenuStartKey(m)
    }

    /// Option + a letter: jump to its stop. A menu stop opens its menu.
    func jumpToPanelStop(_ s: PanelStop) {
        panelMenus.jumpLetters = false
        focusPanelStop(s)
        if s.opensMenu { activatePanelStop(s) }
    }

    /// Going? Yes · Maybe · No, moved by Left and Right.
    func movePanelReply(_ d: Int) {
        guard let e = selectedEvent else { return }
        let order: [ResponseStatus] = [.confirmed, .tentative, .declined]
        let i = order.firstIndex(of: e.myReply) ?? (d > 0 ? -1 : order.count)
        let n = min(max(i + d, 0), order.count - 1)
        if order[n] != e.myReply { setMyReply(order[n]) }
    }

    /// The panel's part of `KeyRouter`: true when the key was used. `typing`: a text field has the keyboard.
    func handlePanelKey(_ k: KeyInput, typing: Bool) -> Bool {
        guard panelTakesKeys else { return false }
        typealias R = ShortcutResolver
        let bare = !k.command && !k.control && !k.option

        if k.option && !k.command && !k.control && !typing, let c = k.characters.lowercased().first,
           let s = PanelTabOrder.jump(c, in: panelStops) {
            jumpToPanelStop(s)
            return true
        }
        // a field's picker (times, date): its field keeps the keyboard
        if typing, let m = panelMenus.open, Self.fieldPickers.contains(m), handleFieldPickerKey(k, menu: m) { return true }
        // the guest field: Up and Down move through the suggestions (the field keeps typing)
        if typing, bare, k.keyCode == R.keyDown || k.keyCode == R.keyUp, panelMenus.stop == .guest,
           moveGuestHighlight(k.keyCode == R.keyDown ? 1 : -1) { return true }
        // Down in such a field opens its picker again (after Esc or a press elsewhere closed it)
        if typing, bare, k.keyCode == R.keyDown, panelMenus.open == nil, let f = panelMenus.stop?.focus, fieldPicker(f) != nil {
            openFieldPicker(f)
            return panelMenus.open != nil
        }
        guard let stop = panelMenus.stop else { return false }
        if typing != stop.isText {
            // the keyboard is somewhere else (a click left the stop behind)
            if !typing { panelMenus.stop = nil }
            return false
        }

        if !typing, let m = panelMenus.open, Self.keyboardMenus.contains(m) {
            let choices = panelMenuChoices(m)
            let i = panelMenus.highlight.flatMap { h in choices.firstIndex { $0.key == h } }
            switch k.keyCode {
            case R.keyDown, R.keyUp:
                guard !choices.isEmpty else { return true }
                let d = k.keyCode == R.keyDown ? 1 : -1
                let n = i.map { ($0 + d + choices.count) % choices.count } ?? (d > 0 ? 0 : choices.count - 1)
                panelMenus.highlight = choices[n].key
                return true
            case R.keyReturn, R.keyEnter:
                pickPanelMenuChoice(choices, i)
                return true
            case R.keyEscape:
                closePanelMenu()
                return true
            case R.keyTab:
                closePanelMenu()
            case R.keyLeft where m == .repeats, R.keyRight where m == .repeats:
                if let h = panelMenus.highlight { stepCustomRepeat(h, by: k.keyCode == R.keyRight ? 1 : -1) }
                return true
            case R.keyDelete where m == .timeZone:
                if !panelMenus.zoneQuery.isEmpty { zoneQueryChanged(String(panelMenus.zoneQuery.dropLast())) }
                return true
            default:
                // the time zone list: typing searches it (Space too: "New York")
                if m == .timeZone, !k.command && !k.control && !k.option, !k.characters.isEmpty,
                   k.characters.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) && $0.value < 0xF700 }) {
                    zoneQueryChanged(panelMenus.zoneQuery + k.characters)
                    return true
                }
                if bare && k.characters == " " { pickPanelMenuChoice(choices, i); return true }
                return bare
            }
        }

        if k.keyCode == R.keyTab && !k.command && !k.control && !k.option {
            movePanelStop(k.shift ? -1 : 1)
            return true
        }
        if typing { return false }

        switch k.keyCode {
        case R.keyEscape:
            panelMenus.stop = nil
            return true
        case R.keyReturn, R.keyEnter:
            guard bare else { return false }
            activatePanelStop(stop)
            return true
        case R.keyDown, R.keyUp:
            guard bare, stop.opensMenu else { return false }
            activatePanelStop(stop)
            return true
        case R.keyLeft, R.keyRight:
            guard bare, stop == .going else { return false }
            movePanelReply(k.keyCode == R.keyRight ? 1 : -1)
            return true
        case R.keyDelete, R.keyForwardDelete:
            guard case .reminder(let m) = stop else { return false }
            let list = panelStops
            let after = list.firstIndex(of: stop).flatMap { $0 + 1 < list.count ? list[$0 + 1] : nil }
            removeReminder(m)
            panelMenus.stop = after
            return true
        default:
            if bare && k.characters == " " { activatePanelStop(stop); return true }
            return false
        }
    }

    private func pickPanelMenuChoice(_ choices: [PanelMenuChoice], _ i: Int?) {
        guard let i, choices.indices.contains(i) else { return }
        let c = choices[i]
        if !c.staysOpen { closePanelMenu() }
        c.run()
    }
}
