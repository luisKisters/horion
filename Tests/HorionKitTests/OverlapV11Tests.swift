import Testing
import Foundation
@testable import HorionKit

/// `OverlapV11`, the overlap rule of design/mockup-v18 (longer behind, titles stay visible, much shorter tucks in, similar
/// lengths share), and the `covered` rule with the visible part of a covered block (mockup-v14).
@Suite("Overlap layout v11 (cascade)")
struct OverlapV11Tests {
    static func m(_ t: String) -> Int { let p = t.split(separator: ":").compactMap { Int($0) }; return p[0] * 60 + p[1] }
    func it(_ id: String, _ s: String, _ e: String) -> V5Item { V5Item(id: id, startMinute: Self.m(s), endMinute: Self.m(e)) }
    func lay(_ items: [V5Item]) -> [String: V5Placement] { Dictionary(uniqueKeysWithValues: OverlapV11.layout(items).map { ($0.id, $0) }) }

    static let W = 178.0
    /// Each block's span in points of a 178 pt column.
    func pts(_ items: [V5Item]) -> [String: (a: Double, b: Double)] {
        Dictionary(uniqueKeysWithValues: OverlapV11.layout(items, width: Self.W).map { ($0.id, ($0.left * Self.W, ($0.left + $0.width) * Self.W)) })
    }
    func near(_ x: Double, _ y: Double) -> Bool { abs(x - y) < 0.02 }

    @Test func aLaterBlockSitsOneStepInAndKeepsTheWidth() {
        let p = pts([it("review", "16:30", "18:45"), it("hiring", "17:00", "18:00")])
        #expect(near(p["review"]!.a, 0) && near(p["review"]!.b, 178))
        #expect(near(p["hiring"]!.a, 12) && near(p["hiring"]!.b, 178))
        let l = OverlapV11.layout([it("review", "16:30", "18:45"), it("hiring", "17:00", "18:00")], width: Self.W)
        #expect(l.map(\.id) == ["review", "hiring"] && !l[0].cut && l[1].cut && l.allSatisfy { $0.indent == 0 })
    }

    @Test func similarLengthsWithinOneTitleLineShareTheWidth() {
        let p = pts([it("a", "10:00", "11:00"), it("b", "10:15", "11:00")])
        #expect(near(p["a"]!.b, 89) && near(p["b"]!.a, 89) && near(p["b"]!.b, 178))
        let q = pts([it("a", "10:00", "11:00"), it("b", "10:22", "11:00")])     // 22 minutes: a cascade step instead
        #expect(near(q["a"]!.b, 178) && near(q["b"]!.a, 12))
    }

    @Test func aMuchShorterBlockTucksInAndTheLongOneKeepsItsWidth() {
        let p = pts([it("dinner", "19:00", "22:00"), it("mum", "19:10", "19:40")])
        #expect(near(p["dinner"]!.a, 0) && near(p["dinner"]!.b, 178) && near(p["mum"]!.a, 89) && near(p["mum"]!.b, 178))
    }

    @Test func theLongerOfBlocksStartingTogetherGoesBehindOnTheLeft() {
        let l = OverlapV11.layout([it("standup", "14:00", "15:00"), it("office", "14:00", "16:00"), it("focus", "14:10", "15:30")], width: Self.W)
        #expect(l.map(\.id) == ["office", "focus", "standup"])
        #expect(l.allSatisfy { abs($0.width - 1.0 / 3) < 1e-9 } && l[0].left == 0)
    }

    @Test func fiveAtOnceKeepCascadingInsteadOfColumns() {
        let p = pts([it("a", "09:00", "12:00"), it("b", "09:30", "12:00"), it("c", "10:00", "12:00"), it("d", "10:30", "12:00"), it("e", "11:00", "12:00")])
        #expect(["a", "b", "c", "d", "e"].enumerated().allSatisfy { k, id in near(p[id]!.a, Double(k) * 12) && near(p[id]!.b, 178) })
    }

    @Test func separateClustersStartOverAndNothingIsFolded() {
        let items = (0..<12).map { V5Item(id: "e\($0)", startMinute: 600 + $0 * 5, endMinute: 720) } + [it("later", "13:00", "14:00")]
        let r = OverlapV11.layout(items)
        #expect(r.count == items.count)
        #expect(r.first { $0.id == "later" }!.left == 0 && !r.first { $0.id == "later" }!.cut && r.first { $0.id == "later" }!.width == 1)
    }

    /// The example days of design/mockup-v18 give the same spans as the mockup's `layoutF`, in the same paint order.
    @Test func matchesTheMockupDays() {
        let days: [(String, [(String, Int, Int)], [(String, Double, Double)])] = [
        ("Your Monday: a long \"test\" block over the school day", [("test", 735, 1185), ("Mathe", 775, 870), ("Biologie", 875, 970), ("Kunst", 975, 1065), ("Paper due", 1065, 1070), ("Vater", 1080, 1170), ("Vater call", 1080, 1170), ("[P1] Review", 1080, 1085)],
         [("test", 0.00, 178.00), ("Mathe", 12.00, 178.00), ("Biologie", 12.00, 178.00), ("Kunst", 12.00, 178.00), ("Vater", 10.00, 66.00), ("Vater call", 66.00, 122.00), ("Paper due", 122.00, 178.00), ("[P1] Review", 122.00, 178.00)]),
        ("Your Tuesday: the one that already looks right", [("test", 720, 990), ("Deutsch", 775, 870), ("Geschichte", 875, 970), ("25th nov 16:00", 960, 970)],
         [("test", 0.00, 178.00), ("Deutsch", 12.00, 178.00), ("Geschichte", 12.00, 178.00), ("25th nov 16:00", 24.00, 178.00)]),
        ("A staircase: five meetings, each 30 min later", [("Planning", 540, 720), ("Design review", 570, 720), ("1:1 Sam", 600, 720), ("Hiring sync", 630, 720), ("Lunch talk", 660, 720)],
         [("Planning", 0.00, 178.00), ("Design review", 12.00, 178.00), ("1:1 Sam", 24.00, 178.00), ("Hiring sync", 36.00, 178.00), ("Lunch talk", 48.00, 178.00)]),
        ("Three start together", [("Standup", 840, 900), ("Office hours", 840, 960), ("Focus", 850, 930)],
         [("Office hours", 0.00, 59.33), ("Focus", 59.33, 118.67), ("Standup", 118.67, 178.00)]),
        ("A busy afternoon", [("Workshop", 780, 1020), ("Call A", 810, 870), ("Call B", 815, 855), ("Review", 870, 930), ("Pickup", 900, 910), ("Sync", 900, 960), ("Ship it", 905, 950), ("Wrap-up", 975, 1020)],
         [("Workshop", 0.00, 178.00), ("Call A", 12.00, 95.00), ("Call B", 95.00, 178.00), ("Review", 12.00, 178.00), ("Sync", 10.00, 66.00), ("Ship it", 66.00, 122.00), ("Pickup", 122.00, 178.00), ("Wrap-up", 12.00, 178.00)]),
        ("A short one before a long one", [("Quick call", 540, 600), ("Deep work", 580, 750), ("Coffee", 630, 660)],
         [("Quick call", 0.00, 178.00), ("Deep work", 12.00, 178.00), ("Coffee", 24.00, 178.00)]),
        ("Family dinner", [("Family dinner", 1140, 1320), ("With Mum", 1150, 1180), ("Jolie / Luis", 1290, 1350)],
         [("Family dinner", 0.00, 178.00), ("With Mum", 89.00, 178.00), ("Jolie / Luis", 12.00, 178.00)]),
        ("Reminders during a long focus block", [("Deep work", 540, 720), ("Standup", 570, 600), ("Take pills", 570, 575), ("Email Anna", 615, 625), ("Call bank", 620, 635), ("Lunch order", 690, 695)],
         [("Deep work", 0.00, 178.00), ("Standup", 12.00, 95.00), ("Take pills", 95.00, 178.00), ("Email Anna", 12.00, 95.00), ("Call bank", 95.00, 178.00), ("Lunch order", 12.00, 178.00)]),
        ("Back-to-back tasks", [("Focus", 840, 1020), ("Task 1", 840, 855), ("Task 2", 855, 870), ("Task 3", 870, 885), ("Task 4", 885, 900), ("Task 5", 900, 915)],
         [("Focus", 0.00, 178.00), ("Task 1", 66.00, 122.00), ("Task 2", 122.00, 178.00), ("Task 3", 10.00, 66.00), ("Task 4", 66.00, 122.00), ("Task 5", 122.00, 178.00)]),
        ("Lecture with a Q&A, a quiz", [("Lecture", 480, 570), ("Q&A", 490, 535), ("Seminar", 585, 645), ("Quiz", 590, 640)],
         [("Lecture", 0.00, 178.00), ("Q&A", 89.00, 178.00), ("Seminar", 0.00, 89.00), ("Quiz", 89.00, 178.00)]),
        ("Two meetings side by side, a task inside", [("Meeting A", 780, 840), ("Meeting B", 780, 840), ("Submit form", 810, 820)],
         [("Meeting A", 0.00, 89.00), ("Meeting B", 89.00, 178.00), ("Submit form", 101.00, 178.00)]),
        ("Three tasks at the same minute", [("Planning", 540, 600), ("Pay rent", 540, 545), ("Water plants", 540, 545), ("Book train", 540, 550)],
         [("Planning", 0.00, 178.00), ("Pay rent", 66.00, 122.00), ("Water plants", 122.00, 178.00), ("Book train", 78.00, 122.00)]),
        ("Short call over two side-by-side blocks", [("Class", 900, 1020), ("Practice", 900, 1020), ("Ping Tom", 940, 950), ("Call", 990, 1010)],
         [("Class", 0.00, 89.00), ("Practice", 89.00, 178.00), ("Ping Tom", 101.00, 178.00), ("Call", 101.00, 178.00)]),
        ]
        for (name, evs, want) in days {
            let got = OverlapV11.layout(evs.map { V5Item(id: $0.0, startMinute: $0.1, endMinute: $0.2) }, width: Self.W)
            #expect(got.map(\.id) == want.map(\.0), "\(name)")
            for (g, w) in zip(got, want) {
                #expect(abs(g.left * Self.W - w.1) < 0.01 && abs((g.left + g.width) * Self.W - w.2) < 0.01, "\(name): \(g.id)")
            }
        }
    }

    @Test func concurrencyCountsSpansAtOneMoment() {
        #expect(OverlapV11.concurrency([(0, 60), (30, 90), (60, 120)]) == 2)      // a span ends before the next starts at its end
        #expect(OverlapV11.concurrency([]) == 0)
    }

    @Test func shortItemsSpan22Minutes() {
        let p = lay([it("task", "09:00", "09:00"), it("standup", "09:30", "09:45")])
        #expect(p["task"]!.endMinute == 9 * 60 + 22 && p["standup"]!.endMinute == 9 * 60 + 52)
    }

    @Test func aBlockCoveredWithinFortyMinutesIsMarked() {
        let math = CalendarMath(timeZone: TimeZone(identifier: "Europe/Berlin")!)
        let day = math.date(year: 2026, month: 11, day: 4)
        func ev(_ id: String, _ s: String, _ e: String) -> CalendarEvent {
            CalendarEvent(id: id, calendarID: "c", title: id, start: math.date(on: day, minutes: Self.m(s)), end: math.date(on: day, minutes: Self.m(e)))
        }
        let r = RangeLayoutBuilder.build(events: [ev("review", "16:30", "18:45"), ev("hiring", "17:00", "18:00"), ev("walk", "19:00", "20:00"),
                                                  ev("talk", "19:45", "20:30")], days: [day], math: math)
        let c = Dictionary(uniqueKeysWithValues: r.timed[0].map { ($0.event.id, $0.placement.covered) })
        #expect(c == ["review": true, "hiring": false, "walk": false, "talk": false])   // walk: talk starts 45 minutes in
        let v = Dictionary(uniqueKeysWithValues: r.timed[0].map { ($0.event.id, $0.placement.visibleMinutes) })
        #expect(v == ["review": 30, "hiring": nil, "walk": 45, "talk": nil])
    }

    /// mockup-v14: a later block beside it (the right half) does not cover it; one drawn over it does, from its start.
    @Test func aBlockBesideItDoesNotCoverIt() {
        let math = CalendarMath(timeZone: TimeZone(identifier: "Europe/Berlin")!)
        let day = math.date(year: 2026, month: 11, day: 4)
        func ev(_ id: String, _ s: String, _ e: String) -> CalendarEvent {
            CalendarEvent(id: id, calendarID: "c", title: id, start: math.date(on: day, minutes: Self.m(s)), end: math.date(on: day, minutes: Self.m(e)))
        }
        // Family dinner 19:00-22:00; "With Mum" 19:10 tucks into the right half; "Jolie / Luis" 21:30 cascades over the dinner.
        let r = RangeLayoutBuilder.build(events: [ev("dinner", "19:00", "22:00"), ev("mum", "19:10", "19:40"), ev("jolie", "21:30", "22:30")],
                                         days: [day], math: math)
        let p = Dictionary(uniqueKeysWithValues: r.timed[0].map { ($0.event.id, $0.placement) })
        #expect(p["mum"]!.left == 0.5 && !p["dinner"]!.covered && p["dinner"]!.visibleMinutes == 150)
    }
}
