import Testing
@testable import HorionKit

/// design/mockup-v20 round 1: Flat Tab through the event panel.
@Suite("Panel tab order")
struct PanelTabOrderTests {
    func ctx(canEdit: Bool = true, writable: Bool = true, allDay: Bool = false, call: PanelStopContext.Call = .add, reminders: [Int] = [10]) -> PanelStopContext {
        PanelStopContext(canEdit: canEdit, writable: writable, dateEditable: canEdit, isAllDay: allDay, going: false,
                         canAddGuests: canEdit, call: call, reminders: reminders)
    }

    @Test func everyControlTopToBottomWithoutDeleteAndClose() {
        #expect(PanelTabOrder.stops(ctx()) == [.title, .date, .start, .end, .allDay, .timeZone, .repeats, .guest, .addCall, .place, .notes,
                                              .calendar, .busy, .visibility, .reminder(10), .addReminder])
        // all day hides the times; a call shows its link and Join
        #expect(PanelTabOrder.stops(ctx(allDay: true, call: .linkAndJoin, reminders: [])) == [.title, .date, .allDay, .repeats, .guest, .link, .join, .place, .notes,
                                                                                             .calendar, .busy, .visibility, .addReminder])
        // an invitation: my own fields and Join only
        #expect(PanelTabOrder.stops(ctx(canEdit: false, call: .joinOnly, reminders: [])) == [.join, .calendar, .busy, .visibility, .addReminder])
        #expect(PanelTabOrder.stops(ctx(canEdit: false, writable: false, call: .none)).isEmpty)
        // a macOS Calendar event: the guest card's Open Accounts button takes the field's place
        var card = ctx(call: .none, reminders: [])
        card.canAddGuests = false
        card.guestsCard = true
        #expect(PanelTabOrder.stops(card) == [.title, .date, .start, .end, .allDay, .timeZone, .repeats, .guestsCard, .place, .notes,
                                             .calendar, .busy, .visibility, .addReminder])
    }

    @Test func tabWrapsAndStartsAtTheEnds() {
        let l: [PanelStop] = [.title, .allDay, .calendar]
        #expect(PanelTabOrder.step(from: .calendar, in: l, by: 1) == .title)
        #expect(PanelTabOrder.step(from: .title, in: l, by: -1) == .calendar)
        #expect(PanelTabOrder.step(from: nil, in: l, by: 1) == .title)
        #expect(PanelTabOrder.step(from: .join, in: l, by: -1) == .calendar)
        #expect(PanelTabOrder.step(from: nil, in: [], by: 1) == nil)
    }

    @Test func jumpLettersAreUniqueAndSkipI() {
        let l = PanelTabOrder.stops(ctx(call: .linkAndJoin))
        let letters = l.compactMap(\.jumpLetter)
        #expect(Set(letters).count == letters.count && !letters.contains("i"))
        #expect(PanelTabOrder.jump("k", in: l) == .calendar && PanelTabOrder.jump("c", in: l) == .link)
    }
}
