import Foundation
import AppKit
import MapKit
import HorionKit

/// The editor's menus (design/mockup-v4 `popHTML`): one open at a time, drawn by `PanelMenuLayer` over the window and anchored to
/// the control that opened it.
enum PanelMenu: String, Hashable, CaseIterable {
    case calendar, reminders, maps, places, call, guests, send, inviteSend, deleteSend
}

/// Edits to an event with guests that are not sent yet (v4 Phase 7b): `base` is what the store has, `edited` what the editor shows.
struct UnsentEdit: Equatable {
    var base: CalendarEvent
    var edited: CalendarEvent
}

/// The open menu and the frames of the controls menus anchor to. A class of its own so that frames changing while the column scrolls
/// re-render only the menu layer, not every view that reads `panelState`.
@MainActor @Observable
final class PanelMenuState {
    var open: PanelMenu?
    /// The location field's suggestions (`places` menu).
    var places: [PlaceSuggestion] = []
    /// The text the suggestions are for.
    var placeQuery = ""
    /// Place search: MapKit's completer in the app, the demo list in demo mode, snapshots and tests (no network).
    var completer: PlaceCompleting?
    /// The guest field's text (`guests` menu).
    var guestQuery = ""
    /// The participant row that shows its details (my own: Going · Maybe · Decline).
    var expandedGuest: String?
    /// "Paste a link…" was chosen: the call row shows a link field.
    var pastingLink = false

    /// Frames (window points, top-left origin) of the editor's rows and controls by name: "menu.<menu>" for the control a menu
    /// opens from, the rest for the walkthrough to point at. Written by `PanelMenuLayer` from the anchor preferences; not observed.
    @ObservationIgnored var frames: [String: CGRect] = [:]
    /// A field the editor should focus (the walkthrough, and "Paste a link…").
    var focusRequest: PanelFocus?
    var focusTick = 0
}

/// Place search behind a protocol, so tests and snapshots never reach the network.
@MainActor
protocol PlaceCompleting: AnyObject {
    var onResults: (([PlaceSuggestion]) -> Void)? { get set }
    func search(_ query: String)
}

/// The demo places (mockup `PLACES`), answered at once.
@MainActor
final class DemoPlaceCompleter: PlaceCompleting {
    var onResults: (([PlaceSuggestion]) -> Void)?
    func search(_ query: String) { onResults?(PlaceSuggestion.filter(PlaceSuggestion.demo, query)) }
}

/// `MKLocalSearchCompleter` (MapKit is a system framework): addresses and places as you type.
@MainActor
final class MapKitPlaceCompleter: NSObject, PlaceCompleting, MKLocalSearchCompleterDelegate {
    var onResults: (([PlaceSuggestion]) -> Void)?
    private let completer = MKLocalSearchCompleter()
    override init() {
        super.init()
        completer.resultTypes = [.address, .pointOfInterest]
        completer.delegate = self
    }
    func search(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.count < 2 { completer.cancel(); onResults?([]); return }
        completer.queryFragment = q
    }
    nonisolated func completerDidUpdateResults(_ c: MKLocalSearchCompleter) {
        let list = c.results.prefix(5).map { PlaceSuggestion(title: $0.title, subtitle: $0.subtitle) }
        MainActor.assumeIsolated { onResults?(Array(list)) }
    }
    nonisolated func completer(_ c: MKLocalSearchCompleter, didFailWithError error: Error) {
        MainActor.assumeIsolated { onResults?([]) }
    }
}

/// The v4 editor: what may change, menus, the location, the call, reminders, colour, replies, unsent changes and the delete dialog.
extension AppModel {
    // MARK: What may change

    /// The shared fields (title, time, guests, call, place, notes) change only on a writable calendar, and only for the organizer when
    /// the event has one (an invitation: my reply, reminders, colour and calendar stay mine).
    func editorCanEdit(_ e: CalendarEvent) -> Bool {
        isWritable(e) && (e.organizer == nil || e.iAmOrganizer)
    }

    func editorContext(_ e: CalendarEvent) -> EditorContext {
        EditorContext(e, canEdit: editorCanEdit(e), isDraft: draft?.id == e.id)
    }

    /// Edits to an event I organise with guests wait for "Send update" when the store can send updates (Google). EventKit saves at once.
    func buffersUpdates(_ e: CalendarEvent) -> Bool {
        store.canSendUpdates(calendarID: e.calendarID) && e.iAmOrganizer && e.attendees.contains { !$0.isMe } && draft?.id != e.id
    }

    /// The store writes my reply (Google). EventKit shows Going? read-only.
    var canRespond: Bool { store.canRespond }
    /// Going? and my own row write my reply for this event's calendar (Google yes, EventKit no).
    func canRespond(_ e: CalendarEvent) -> Bool { store.canRespond(calendarID: e.calendarID) }

    // MARK: Menus

    func openPanelMenu(_ m: PanelMenu) {
        panelMenus.open = panelMenus.open == m ? nil : m
    }
    func closePanelMenu() { panelMenus.open = nil }

    /// Another event (or none) is selected: menus, the expanded row, typed queries and suggestions belong to the old one.
    func resetEditorTransients() {
        panelMenus.open = nil
        panelMenus.expandedGuest = nil
        panelMenus.guestQuery = ""
        panelMenus.places = []
        panelMenus.placeQuery = ""
        panelMenus.pastingLink = false
    }

    /// Moves the keyboard to an editor field.
    func focusEditorField(_ f: PanelFocus) { panelMenus.focusRequest = f; panelMenus.focusTick += 1 }

    // MARK: Unsent changes

    var selectedUnsent: UnsentEdit? { selectedEventID.flatMap { panelState.unsent[$0] } }

    /// Called by `updateSelected`: keeps a change to the shared fields in the editor until it is sent. My own fields (reminders,
    /// colour, calendar, reply) are written at once, under the held change. Returns false when the change is not held.
    func holdUnsent(before: CalendarEvent, after e: CalendarEvent) -> Bool {
        let held = panelState.unsent[e.id]
        guard held != nil || (buffersUpdates(e) && EditorRows.sharedChanged(before, e)) else { return false }
        let base = held?.base ?? before
        let mine = EditorRows.personal(of: e, onto: base)
        panelState.unsent[e.id] = EditorRows.sharedChanged(base, e) ? UnsentEdit(base: mine, edited: e) : nil
        if mine != base {
            flushPendingEdit()
            commit(mine, span: .this, old: nil)
        } else {
            reload()
        }
        return true
    }

    /// Send update (notify) or Save without sending: the held change goes to the store (a repeating event asks which occurrences first).
    func sendUnsent(notify: Bool) {
        guard let id = selectedEventID else { return }
        closePanelMenu()
        if let u = panelState.unsent[id], askSpan(base: u.base, edited: u.edited, old: nil, notify: notify) { return }
        if sendUnsent(id, notify: notify) { showToast(notify ? "Update sent" : "Saved without sending") }
    }

    /// Writes one held change. The hold is cleared only once the store took it: a failed write keeps the edits (and says so).
    @discardableResult
    func sendUnsent(_ id: String, notify: Bool) -> Bool {
        guard let u = panelState.unsent[id] else { return false }
        do {
            try store.update(u.edited, span: .this, notify: notify)
        } catch {
            showToast("Could not save event. Your changes are kept.")
            return false
        }
        panelState.unsent[id] = nil
        storeChanged()
        return true
    }

    /// Every held change, for the quit dialog. Returns false when one of them could not be written.
    @discardableResult
    func sendAllUnsent(notify: Bool) -> Bool {
        Array(panelState.unsent.keys).sorted().reduce(true) { ok, id in sendUnsent(id, notify: notify) && ok }
    }

    /// Discard: the event goes back to what the store has.
    func discardUnsent() {
        guard let id = selectedEventID, panelState.unsent[id] != nil else { return }
        closePanelMenu()
        panelState.unsent[id] = nil
        storeChanged()
    }

    /// ⌘↩: send the held change, or save (and invite) the event being created.
    func sendShortcut() -> Bool {
        if selectedUnsent != nil { sendUnsent(notify: true); return true }
        if isDraftOpen { saveDraft(); return true }
        return false
    }

    // MARK: Delete with guests

    /// Deleting an event I organise with guests asks first: guests get a cancellation email, or not.
    func deleteNeedsGuestDialog(_ e: CalendarEvent) -> Bool {
        store.canSendUpdates(calendarID: e.calendarID) && e.iAmOrganizer && e.attendees.contains { !$0.isMe }
    }

    func deleteWithGuests(_ id: String, notify: Bool) {
        closePanelMenu()
        guard let e = event(id: id) else { overlay = nil; return }
        if delete(e, span: .this, notify: notify) { panelState.unsent[id] = nil }
    }

    /// "This and following" only where it differs from the other two: the series has an occurrence before this one (else it
    /// is "All events") and one after it (else it is "This event").
    func deleteOffersFollowing(_ e: CalendarEvent) -> Bool {
        guard e.isRecurring else { return false }
        let series = store.series(of: e)
        return series.contains { $0.start < e.start } && series.contains { $0.start > e.start }
    }

    /// The recurring-delete and recurring-edit dialogs' buttons, left to right ("This and following" only where it is offered).
    /// An edit asks about the occurrence where it was, not where the held change put it.
    func spanChoices(_ id: String) -> [SpanChoice] {
        let e = recurringEdit.flatMap { $0.base.id == id ? $0.base : nil } ?? event(id: id)
        let following = e.map(deleteOffersFollowing) ?? false
        return following ? [.cancel, .all, .future, .this] : [.cancel, .all, .this]
    }

    /// ←/→ and A/D move the focus and stop at the ends; Tab and ⇧Tab move it and wrap around.
    func moveSpanChoice(_ id: String, by step: Int, wrap: Bool) {
        let all = spanChoices(id)
        let i = all.firstIndex(of: spanChoice) ?? all.count - 1
        let j = wrap ? (i + step + all.count) % all.count : min(max(i + step, 0), all.count - 1)
        spanChoice = all[j]
    }

    /// Return (or a click) on one of the recurring-delete dialog's buttons.
    func chooseDelete(_ id: String, _ choice: SpanChoice) {
        switch choice {
        case .cancel: closeOverlay()
        case .all: deleteRecurring(id, span: .all, notify: deleteNotify)
        case .future: deleteRecurring(id, span: .future, notify: deleteNotify)
        case .this: deleteRecurring(id, span: .this, notify: deleteNotify)
        }
    }

    // MARK: Edit a repeating event

    /// A move or resize from the grid or the keyboard: a repeating event asks which occurrences first.
    func commitMove(_ e: CalendarEvent, old: CalendarEvent) {
        if askSpan(base: old, edited: e, old: old, notify: nil) { return }
        commit(e, span: .this, old: old)
    }

    /// A changed time of a repeating event (not the event being created) waits for the recurring-edit dialog. Returns false
    /// when nothing is asked. `old`: undo goes back to it (this occurrence only). `notify`: the held change of an event with guests.
    func askSpan(base: CalendarEvent, edited: CalendarEvent, old: CalendarEvent?, notify: Bool?) -> Bool {
        guard draft?.id != edited.id, store.repeats(base) else { return false }
        let timeChanged = base.start != edited.start || base.end != edited.end || base.isAllDay != edited.isAllDay
        guard timeChanged || notify != nil else { return false }
        flushPendingEdit()
        recurringEdit = RecurringEdit(base: base, edited: edited, old: old, notify: notify)
        spanChoice = .this
        overlay = .editRecurring(edited.id)
        reload()
        return true
    }

    /// Return (or a click) on one of the recurring-edit dialog's buttons. Cancel puts the event back where it was (a held change
    /// of an event with guests stays held).
    func chooseEdit(_ id: String, _ choice: SpanChoice) {
        guard let r = recurringEdit, r.edited.id == id else { overlay = nil; return }
        if choice == .cancel { overlay = nil; return }   // the overlay's didSet drops the held change
        recurringEdit = nil
        overlay = nil
        let span: EditSpan
        switch choice {
        case .cancel: return
        case .all: span = .all
        case .future: span = .future
        case .this: span = .this
        }
        if let notify = r.notify {
            do { try store.update(r.edited, span: span, notify: notify) } catch { showToast("Could not save event. Your changes are kept."); storeChanged(); return }
            panelState.unsent[id] = nil
            storeChanged()
            showToast(notify ? "Update sent" : "Saved without sending")
        } else if span == .this {
            commit(r.edited, span: .this, old: r.old)
        } else {
            // undo moves one occurrence back: not offered for a change to several
            do { _ = try store.update(r.edited, span: span); storeChanged(); selectedEventID = id } catch { showToast("Could not save event"); storeChanged() }
        }
    }

    /// The recurring-delete dialog of an event with guests: `notify` says whether guests get the cancellation email.
    func deleteRecurring(_ id: String, span: EditSpan, notify: Bool) {
        guard let e = event(id: id) else { overlay = nil; return }
        if delete(e, span: span, notify: notify) { panelState.unsent[id] = nil }
    }

    // MARK: Fields

    func setSelectedTitle(_ t: String) { updateSelected { $0.title = t } }

    /// The notes as typed: Google's Meet block stays at the end, hidden.
    func setSelectedNotes(_ text: String) { updateSelected { $0.notes = MeetNotes.replacingVisible(in: $0.notes, with: text) } }

    func toggleReminder(_ m: Int) { updateSelected { $0.reminders = Reminders.toggled($0.reminders, m) } }
    func removeReminder(_ m: Int) { updateSelected { $0.reminders.removeAll { $0 == m } } }

    func setSelectedCalendar(_ id: String) { updateSelected { $0.calendarID = id } }
    /// Nil: the calendar's colour.
    func setSelectedColor(_ hex: String?) { updateSelected { $0.colorHex = hex } }

    /// My reply (Going? or my own participant row). Not an update to send: Google patches my entry only.
    func setMyReply(_ s: ResponseStatus) {
        guard let id = selectedEventID else { return }
        setReply(s, eventID: id)
    }

    /// My reply to one event, from the editor or the menu bar: only when the store writes replies, I am on the guest list and I do
    /// not organise it. A reply is mine, not an update to send: it goes to the store at once, under a held change if there is one.
    func setReply(_ s: ResponseStatus, eventID id: String) {
        // my events (I organise them) have nothing to answer; an invitation with an organizer must list me
        guard var e = event(id: id), canRespond(e), !e.iAmOrganizer, e.organizer == nil || e.attendees.contains(where: \.isMe),
              isWritable(e), e.status != s else { return }
        if var u = panelState.unsent[id] {
            u.base.status = s; u.edited.status = s
            e = u.base
            panelState.unsent[id] = u
        } else {
            e.status = s
        }
        flushPendingEdit()
        do { try store.update(e, span: .this) } catch { showToast("Could not save your reply") }
        storeChanged()
    }

    // MARK: Location

    func setLocationText(_ text: String) {
        updateSelected { $0.location = text }
        searchPlaces(text)
    }

    func searchPlaces(_ text: String) {
        if panelMenus.completer == nil { panelMenus.completer = store.isDemo ? DemoPlaceCompleter() : MapKitPlaceCompleter() }
        panelMenus.placeQuery = text
        let id = selectedEventID
        panelMenus.completer?.onResults = { [weak self] list in
            guard let self, self.panelMenus.placeQuery == text, self.selectedEventID == id else { return }
            self.panelMenus.places = list
            if !list.isEmpty { self.panelMenus.open = .places } else if self.panelMenus.open == .places { self.panelMenus.open = nil }
        }
        panelMenus.completer?.search(text)
    }

    func pickPlace(_ text: String) {
        panelMenus.places = []
        panelMenus.placeQuery = text
        closePanelMenu()
        updateSelected { $0.location = text }
        blurTick += 1
    }

    enum MapsApp { case apple, google }
    func openMaps(_ app: MapsApp) {
        closePanelMenu()
        guard let loc = selectedEvent?.location, let url = app == .apple ? MapLinks.apple(loc) : MapLinks.google(loc) else { return }
        if !opensOutside { showToast(app == .apple ? "Opens Apple Maps" : "Opens Google Maps"); return }
        NSWorkspace.shared.open(url)
    }

    func copyLocation() {
        closePanelMenu()
        guard let loc = selectedEvent?.location, !loc.isEmpty else { return }
        copyToPasteboard(loc)
        showToast("Copied address")
    }

    /// Headless runs and unit tests (no application object) never open other apps or touch the pasteboard.
    var opensOutside: Bool { !options.isHeadless && NSApp != nil }

    func copyToPasteboard(_ s: String) {
        guard opensOutside else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }

    // MARK: Call

    /// Google Meet for a new event: the link is made when it is saved (demo store: a made-up code).
    func addMeet() {
        closePanelMenu()
        guard let e = selectedEvent else { return }
        if isDraftOpen { panelState.newMeet.insert(e.id); reload(); return }
        updateSelected { $0.conferencing = newMeetLink(e) }
    }

    /// "Google Meet": a made-up link in the demo; Google makes the real one when the event is saved (`GoogleMapping.newMeetLink`).
    func newMeetLink(_ e: CalendarEvent) -> String {
        store.isDemo ? "https://meet.google.com/" + Self.meetCode(e.id) : GoogleMapping.newMeetLink
    }

    /// A made-up Meet code ("abc-defg-hij") from the event id.
    nonisolated static func meetCode(_ seed: String) -> String {
        var h: UInt64 = 1469598103934665603
        for b in seed.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        let a = Array("abcdefghijkmnopqrstuvwxyz")
        let letters = (0..<10).map { i in a[Int((h >> UInt64(i * 6)) % UInt64(a.count))] }
        return String(letters[0..<3]) + "-" + String(letters[3..<7]) + "-" + String(letters[7..<10])
    }

    func startPastingLink() { closePanelMenu(); panelMenus.pastingLink = true }

    /// The link field under Join: a web address replaces the call; empty text removes it. Returns false for anything else.
    func setCallLink(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { removeCall(); return true }
        panelMenus.pastingLink = false
        return setVideoLink(t)
    }

    func removeCall() {
        guard let e = selectedEvent else { return }
        panelState.newMeet.remove(e.id)
        panelMenus.pastingLink = false
        updateSelected { ev in
            // the call goes everywhere it was found, or the next parse would bring it back from the notes or the location
            ev.conferencing = ""
            ev.notes = CallLink.removingCalls(from: MeetNotes.visible(ev.notes).text)
            ev.location = CallLink.removingCalls(from: ev.location)
        }
        reload()
    }

    /// The link Copy puts on the pasteboard: the parsed call's URL, else the trimmed text in the call field (nil when there is none).
    func callLinkText(_ e: CalendarEvent) -> String? {
        if let c = CallLink.parse(e) { return c.url.absoluteString }
        let link = e.conferencing.trimmingCharacters(in: .whitespacesAndNewlines)
        return link.isEmpty ? nil : link
    }

    /// design/call-link round 3: Copy next to the link and next to Join on the Up next card. Plain text only; the feedback is the
    /// button's own check for 1.5 s, no toast. Writes to `pasteboard` when given (tests), else to the general one outside headless runs.
    /// Returns whether there was a link to copy.
    @discardableResult
    func copyCallLink(_ event: CalendarEvent? = nil, to pasteboard: NSPasteboard? = nil) -> Bool {
        guard let e = event ?? selectedEvent, let link = callLinkText(e) else { return false }
        if let pasteboard {
            pasteboard.clearContents()
            pasteboard.setString(link, forType: .string)
        } else {
            copyToPasteboard(link)
        }
        return true
    }

    // MARK: Participants

    func removeSelectedGuest(email: String, name: String?) {
        updateSelected { ev in
            if let i = ev.attendees.firstIndex(where: { !$0.isMe && $0.email == email && $0.name == name }) { ev.attendees.remove(at: i) }
        }
    }

    /// Puts back a guest removed in the unsent change.
    func restoreGuest(_ a: Attendee) { updateSelected { ev in if !ev.attendees.contains(a) { ev.attendees.append(a) } } }

    func restoreCall() {
        guard let u = selectedUnsent else { return }
        updateSelected { $0.conferencing = u.base.conferencing }
    }

    /// The people the guest field suggests: the store's people, then Contacts and Google contacts (`peopleDirectory`), not on the list
    /// yet, matched by name or address.
    func guestSuggestions(_ q: String) -> [Teammate] {
        guard let e = selectedEvent else { return [] }
        let on = Set(e.attendees.map { $0.email.lowercased() })
        let list = peopleDirectory().filter { !on.contains($0.email.lowercased()) }
        let query = q.trimmingCharacters(in: .whitespaces)
        // empty field: the four most recent people (the demo order stands in for recency)
        return query.isEmpty ? Array(list.prefix(4)) : Array(FuzzyMatcher.filter(list, query: query) { "\($0.name) \($0.email)" }.prefix(6))
    }

    func addGuest(_ t: Teammate) {
        updateSelected { $0.attendees.append(Attendee(email: t.email, name: t.name)) }
        panelMenus.guestQuery = ""
        closePanelMenu()
    }


    /// "Find a new time": the guests' calendars side by side (Meet with).
    func findNewTime() { store.canOverlayTeammates ? openPalette(.meet) : showToast(Self.meetWithUnavailable) }

    func copyGuestAddress(_ a: Attendee) {
        guard !a.email.isEmpty else { return }
        copyToPasteboard(a.email)
        showToast("Copied \(a.email)")
    }
}

extension PanelText {
    /// The editor's length (mockup `dur`): "1 h", "1 h 30 min", "45 min".
    static func editorDuration(_ minutes: Int) -> String {
        let m = max(0, minutes)
        return m >= 60 ? "\(m / 60) h" + (m % 60 > 0 ? " \(m % 60) min" : "") : "\(m) min"
    }

    /// The editor's repeat line: "Every week on Sun" for one weekday, else the general text.
    static func editorRepeats(_ e: CalendarEvent, _ fmt: Fmt) -> String? {
        guard let t = repeats(e, fmt) else { return nil }
        if t.hasPrefix("Weekly on "), !t.contains(",") { return "Every week on " + t.dropFirst("Weekly on ".count) }
        return t
    }

    /// A guest's reply as the participant list's tooltip names it.
    static func replyName(_ s: ResponseStatus) -> String {
        switch s {
        case .confirmed: "Going"
        case .tentative: "Maybe"
        case .declined: "Declined"
        case .needsAction: "Awaiting"
        }
    }
}

/// A change to a repeating event that waits for the recurring-edit dialog: `base` is what the store has, `edited` the change.
struct RecurringEdit: Equatable {
    var base: CalendarEvent
    var edited: CalendarEvent
    /// Undo goes back to it ("This event" only); nil for a change from the editor.
    var old: CalendarEvent?
    /// The held change of an event with guests: Send update (true) or Save without sending (false). Nil: no guests to tell.
    var notify: Bool?
}

/// A button of the recurring-delete and recurring-edit dialogs.
enum SpanChoice: Equatable {
    case cancel, all, future, this
    var title: String {
        switch self { case .cancel: "Cancel"; case .all: "All events"; case .future: "This and following"; case .this: "This event" }
    }
}
