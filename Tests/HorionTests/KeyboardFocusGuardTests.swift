import Testing
import Foundation
import CoreGraphics
import HorionKit
@testable import Horion

/// Regression guards for bugs found by hand: each test names the failure it would catch.
@MainActor
@Suite("Keyboard and focus guards")
struct KeyboardFocusGuardTests {
    func timed(_ m: AppModel, _ title: String, day: Int) -> PlacedEvent {
        m.layout.timed[day].first { $0.event.title == title }!
    }

    // MARK: Search behind an open event

    /// With an event open in the right column, `/` must still give the search field the keyboard, and typing must replace the
    /// event with the results (the detail view used to keep the column, hiding them).
    @Test func searchReachesTheFieldAndItsResultsWhileAnEventIsOpen() {
        let m = makeModelV4()
        let open = m.layout.timed[0].first!.event
        m.select(eventID: open.id)
        m.rightColumnVisible = false
        #expect(KeyRouter().handle(KeyInput(characters: "/", keyCode: 44), typing: false, window: nil, model: m))
        #expect(m.chromeState.searchFocused && m.rightColumnVisible && m.overlay == nil)
        m.setColumnQuery("walk")
        #expect(m.selectedEventID == nil, "the open event must give the column to the results")
        #expect(m.columnSearching && !m.columnResults.isEmpty)
    }

    /// The same through the command menu's Search events.
    @Test func commandMenuSearchReachesTheResultsWhileAnEventIsOpen() {
        let m = makeModelV4()
        m.select(eventID: m.layout.timed[0].first!.event.id)
        m.openPalette(.all)
        m.run(.searchEvents)
        #expect(m.overlay == nil && m.chromeState.searchFocused)
        m.setColumnQuery("walk")
        #expect(m.selectedEventID == nil && !m.columnResults.isEmpty)
    }

    // MARK: Narrow create area

    /// Next to a block that fills its day column there is a free strip of at least 10 pt where a press is empty grid and a drag
    /// creates an event (blocks used to leave about 2 pt). An empty slot is empty grid across the whole column.
    @Test func pressingBesideAFullWidthBlockCreates() {
        let m = makeModel()
        let g = m.gridGeometry
        let deep = timed(m, "Deep work", day: 1)
        #expect(deep.placement.left == 0 && deep.placement.width == 1)
        let r = g.rect(for: deep)
        let columnRight = 2 * g.dayWidth
        #expect(columnRight - r.maxX >= 10)
        let y = r.midY
        for x in stride(from: r.maxX + 0.5, to: columnRight, by: 1) {
            guard case .empty(let d, _)? = m.hitTest(CGPoint(x: x, y: y)) else { Issue.record("x \(x) is not empty grid"); return }
            #expect(d == 1)
        }
        let p = CGPoint(x: columnRight - 5, y: y)
        m.gridMouseDown(p)
        m.gridMouseDragged(CGPoint(x: p.x, y: p.y + g.hourHeight))
        #expect(m.dragPreview?.kind == .create && m.dragPreview?.dayIndex == 1)

        let empty = g.yPos(3 * 60 + 30)      // 03:30, nothing on Tuesday
        for x in stride(from: g.dayWidth + 0.5, to: columnRight, by: 1) {
            guard case .empty(1, _)? = m.hitTest(CGPoint(x: x, y: empty)) else { Issue.record("x \(x) of an empty slot is not empty grid"); return }
        }
    }

    // MARK: Recurring delete default

    /// The recurring-delete dialog opens on "This event" every time, even after the focus was moved the last time, and Return
    /// then deletes only this occurrence.
    @Test func returnInTheRecurringDeleteDialogDeletesOnlyThisEvent() throws {
        let m = makeModel()
        let ev = timed(m, "Long run", day: 6).event
        var next = ev; next.id = "guard.long-run.next"
        next.start = m.math.addDays(ev.start, 7); next.end = m.math.addDays(ev.end, 7)
        try m.store.create(next)
        let router = KeyRouter()
        let esc = KeyInput(characters: "\u{1B}", keyCode: ShortcutResolver.keyEscape)
        let ret = KeyInput(characters: "\r", keyCode: ShortcutResolver.keyReturn)

        m.select(eventID: ev.id)
        m.requestDeleteSelected()
        #expect(m.overlay == .deleteRecurring(ev.id))
        #expect(router.handle(KeyInput(characters: "a"), typing: false, window: nil, model: m))
        #expect(m.spanChoice == .all)
        #expect(router.handle(esc, typing: false, window: nil, model: m))
        #expect(m.overlay == nil && m.store.series(of: ev).count == 2)

        m.select(eventID: ev.id)
        m.requestDeleteSelected()
        #expect(m.spanChoice == .this)
        #expect(router.handle(ret, typing: false, window: nil, model: m))
        #expect(m.overlay == nil)
        #expect(m.event(id: ev.id) == nil)
        #expect(m.store.series(of: next).map(\.id) == [next.id])
    }
}
