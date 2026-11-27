import Foundation

/// One keyboard stop in the event panel (design/mockup-v20, "Flat Tab"): every field, switch, button and menu, top to bottom.
/// Delete and Close are not stops.
public enum PanelStop: Hashable, Sendable {
    case title, date, start, end, allDay, timeZone, repeats, guest, guestsCard, going, addCall, link, join, place, notes, calendar, busy, visibility
    case reminder(Int)
    case addReminder

    /// A text field: the keyboard types into it.
    public var isText: Bool {
        switch self {
        case .title, .date, .start, .end, .guest, .link, .place, .notes: true
        default: false
        }
    }

    /// Return, Space or Down opens a menu at this stop.
    public var opensMenu: Bool {
        switch self {
        case .timeZone, .repeats, .addCall, .calendar, .busy, .visibility, .reminder, .addReminder: true
        default: false
        }
    }

    /// Option + this letter jumps to the stop (Option held shows the letters). No I: Option-I shows and hides the right column.
    public var jumpLetter: Character? {
        switch self {
        case .title: "t"
        case .date: "d"
        case .start: "s"
        case .end: "e"
        case .allDay: "a"
        case .timeZone: "z"
        case .repeats: "r"
        case .guest, .guestsCard: "p"
        case .going: "g"
        case .addCall, .link: "c"
        case .join: "j"
        case .place: "l"
        case .notes: "n"
        case .calendar: "k"
        case .busy: "b"
        case .visibility: "v"
        case .addReminder: "m"
        case .reminder: nil
        }
    }
}

/// What decides which stops the panel has.
public struct PanelStopContext: Equatable, Sendable {
    /// The call row: nothing to reach, "Add conferencing", the link field, the link field and Join, or Join only (read-only).
    public enum Call: Equatable, Sendable { case none, add, link, linkAndJoin, joinOnly }

    /// I may change the shared fields (title, time, guests, call, place, notes).
    public var canEdit: Bool
    /// I may change my own fields (calendar, availability, visibility, reminders).
    public var writable: Bool
    /// The date field takes typing (one day only).
    public var dateEditable: Bool
    public var isAllDay: Bool
    public var going: Bool
    public var canAddGuests: Bool
    /// The NoGuestsCard takes the guest field's place (a macOS Calendar event I may change): its "Open Accounts" button is a stop.
    public var guestsCard: Bool
    public var call: Call
    public var reminders: [Int]

    public init(canEdit: Bool, writable: Bool, dateEditable: Bool, isAllDay: Bool, going: Bool, canAddGuests: Bool, guestsCard: Bool = false, call: Call, reminders: [Int]) {
        self.canEdit = canEdit; self.writable = writable; self.dateEditable = dateEditable; self.isAllDay = isAllDay
        self.going = going; self.canAddGuests = canAddGuests; self.guestsCard = guestsCard; self.call = call; self.reminders = reminders
    }
}

public enum PanelTabOrder {
    /// The stops in the order the panel shows them (`EditorRows.rows`).
    public static func stops(_ c: PanelStopContext) -> [PanelStop] {
        var s: [PanelStop] = []
        if c.canEdit { s.append(.title) }
        if c.dateEditable { s.append(.date) }
        if c.canEdit && !c.isAllDay { s += [.start, .end] }
        if c.canEdit { s.append(.allDay) }
        if c.canEdit && !c.isAllDay { s.append(.timeZone) }
        if c.canEdit { s.append(.repeats) }
        if c.canAddGuests { s.append(.guest) } else if c.canEdit && c.guestsCard { s.append(.guestsCard) }
        if c.going { s.append(.going) }
        switch c.call {
        case .none: break
        case .add: s.append(.addCall)
        case .link: s.append(.link)
        case .linkAndJoin: s += [.link, .join]
        case .joinOnly: s.append(.join)
        }
        if c.canEdit { s += [.place, .notes] }
        if c.writable {
            s += [.calendar, .busy, .visibility]
            s += c.reminders.map(PanelStop.reminder)
            s.append(.addReminder)
        }
        return s
    }

    /// The stop `by` steps from `from`, wrapping at both ends. From nothing (or a stop that is gone), Tab starts at the top and
    /// Shift-Tab at the bottom.
    public static func step(from: PanelStop?, in list: [PanelStop], by d: Int) -> PanelStop? {
        guard !list.isEmpty else { return nil }
        guard let from, let i = list.firstIndex(of: from) else { return d >= 0 ? list.first : list.last }
        let n = list.count
        return list[((i + d) % n + n) % n]
    }

    /// The stop for an Option + letter jump.
    public static func jump(_ letter: Character, in list: [PanelStop]) -> PanelStop? {
        list.first { $0.jumpLetter == letter }
    }
}
