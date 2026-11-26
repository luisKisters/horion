import AppKit
import SwiftUI
import HorionKit

/// `--walkthrough all-day-drag`: making multi-day all-day events by dragging in the week. Unlike the other tours, the pointer here is
/// real mouse-down / dragged / up NSEvents sent to the window, so SwiftUI's own gestures (drag before tap) in `AllDayView` and
/// `DayHeaderView` are what create the events.
@MainActor
enum WalkthroughAllDay {
    /// Presses at `a`, drags to `b` over `duration` seconds and releases, with real events (window points, top-left origin).
    static func mouseDrag(_ d: Driver, from a: CGPoint, to b: CGPoint, duration: Double = 0.9) {
        d.moveCursor(to: a, duration: 0.5)
        d.recordClick()
        let h = d.size.height, win = d.win.window
        func send(_ type: NSEvent.EventType, _ p: CGPoint) {
            if let e = NSEvent.mouseEvent(with: type, location: NSPoint(x: p.x, y: h - p.y), modifierFlags: [],
                                          timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: win.windowNumber,
                                          context: nil, eventNumber: 0, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1) {
                win.sendEvent(e)
            }
        }
        send(.leftMouseDown, a)
        d.settle(2)
        d.gesture(duration) { e in
            let p = CGPoint(x: a.x + (b.x - a.x) * e, y: a.y + (b.y - a.y) * e)
            d.cursor = p
            send(.leftMouseDragged, p)
        }
        d.play(0.4) { send(.leftMouseUp, b) }
    }

    static func run(_ d: Driver, _ m: AppModel) {
        let f = { m.gridState.allDayFrame }
        let n = m.visibleDays.count
        let dw = f().width / CGFloat(max(1, n))
        let days = m.visibleDays
        func span(_ e: CalendarEvent?) -> (Int, Int)? {
            guard let e, let a = days.firstIndex(where: { m.math.isSameDay($0, e.start) }) else { return nil }
            return (a, m.math.daysBetween(e.start, e.end))
        }
        /// A point in day `i`'s create strip (always free, even on a full day), in the first lane.
        func strip(_ i: Int) -> CGPoint { CGPoint(x: f().minX + CGFloat(i + 1) * dw - 6, y: f().minY + AllDayView.topPad + AllDayView.chip / 2) }
        /// A point on day `i`'s date in the day header above the all-day lane.
        func date(_ i: Int) -> CGPoint { CGPoint(x: f().minX + CGFloat(i) * dw + 30, y: f().minY - DayHeaderView.height / 2) }
        let before = m.store.events(in: DateInterval(start: days[0], end: m.math.addDays(days[n - 1], 1))).filter(\.isAllDay).count

        d.section("Drag across the all-day lane")
        d.say("Week view: the all-day lane")
        d.moveCursor(to: CGPoint(x: f().midX, y: f().minY - 60), duration: 0.4)
        d.frame(hold: 1.2)
        d.say("Drag from Tuesday's free edge to Friday")
        mouseDrag(d, from: strip(1), to: strip(4))
        d.check(m.isDraftOpen && m.draft?.isAllDay == true, "the drag opens a new all-day event")
        d.check(span(m.draft).map { $0 == (1, 4) } == true, "it runs Tuesday to Friday, 4 days (\(String(describing: span(m.draft))))")
        d.hold(0.8)
        d.say("Name it, Return saves", keys: ["\u{21A9}"])
        // The offscreen window hands the title the field editor late: nudge until it has it.
        let deadline = Date().addingTimeInterval(4)
        while !(d.win.window.firstResponder is NSTextView) && Date() < deadline {
            m.requestTitleFocus()
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        }
        d.type("Offsite")
        d.check(m.draft?.title == "Offsite", "title typed (\(m.draft?.title ?? "nil"))")
        d.play(0.4) { d.special("return") }
        d.settle(6)
        d.frame(hold: 0.4)
        let saved = m.store.events(in: DateInterval(start: days[0], end: m.math.addDays(days[n - 1], 1))).first { $0.title == "Offsite" }
        d.check(saved?.isAllDay == true && span(saved).map { $0 == (1, 4) } == true, "Offsite is saved as a 4-day all-day event")
        d.hold(1.4)

        d.section("Drag backwards across the dates")
        d.say("Or drag across the dates, right to left too")
        mouseDrag(d, from: date(5), to: date(2))
        d.check(m.isDraftOpen && m.draft?.isAllDay == true, "dragging over the dates opens a new all-day event")
        d.check(span(m.draft).map { $0 == (2, 4) } == true, "dragged right to left, Saturday back to Wednesday (\(String(describing: span(m.draft))))")
        d.hold(1.0)
        d.say("Esc discards it", keys: ["esc"])
        d.special("esc")
        d.settle(6)
        d.frame(hold: 1.0)
        d.check(!m.isDraftOpen, "Esc drops the draft")

        d.section("A click is still one day")
        d.say("A single click still makes a one-day event")
        d.clickPoint(strip(6), seconds: 0.6)
        d.check(m.isDraftOpen && span(m.draft).map { $0 == (6, 1) } == true, "a click makes a one-day all-day event (\(String(describing: span(m.draft))))")
        d.hold(1.0)
        d.special("esc")
        d.settle(6)
        d.frame(hold: 0.8)
        let after = m.store.events(in: DateInterval(start: days[0], end: m.math.addDays(days[n - 1], 1))).filter(\.isAllDay).count
        d.check(after == before + 1, "only Offsite was added (\(before) -> \(after))")
        d.endCaption()
    }
}
