import AppKit
import SwiftUI
import CalendrKit

/// Scripted tour of every feature. Keyboard shortcuts are real NSEvents; grid pointer gestures call the model functions the SwiftUI DragGesture forwards to. Inspector fields that are pickers/menus (calendar, reminder, all-day) call the same
/// `AppModel.updateSelected` setter their bindings call; sidebar/toolbar buttons call the same model methods their actions call.
@MainActor
enum Walkthrough {
    static func run(_ o: LaunchOptions) -> Int32 {
        let model = HeadlessRunner.makeModel(o)
        let rec = o.record.flatMap { VideoRecorder(url: URL(fileURLWithPath: $0), width: Int(o.size.width), height: Int(o.size.height)) }
        if o.record != nil && rec == nil { print("could not open recorder"); return 2 }
        let d = Driver(model: model, size: o.size, recorder: rec)
        let started = Date()
        tour(d, model)
        rec?.finish()
        let secs = rec.map { String(format: "%.1f", $0.seconds) } ?? "-"
        print("walkthrough: \(d.checks) checks, \(d.failures.count) failures, video \(secs)s, wall \(String(format: "%.1f", Date().timeIntervalSince(started)))s")
        if !d.failures.isEmpty { d.failures.forEach { print(" - \($0)") } }
        return d.failures.isEmpty ? 0 : 1
    }

    static func placed(_ m: AppModel, _ title: String, day: Int) -> PlacedEvent? { m.layout.timed[day].first { $0.event.title == title } }

    static func centerOf(_ d: Driver, _ p: PlacedEvent, yFraction: Double = 0.4) -> CGPoint {
        let r = d.model.gridGeometry.rect(for: p)
        return CGPoint(x: r.minX + r.width * 0.5, y: r.minY + r.height * yFraction)
    }

    static func tour(_ d: Driver, _ m: AppModel) {
        let math = m.math
        func day(_ mo: Int, _ dd: Int) -> Date { math.date(year: 2026, month: mo, day: dd) }
        func startDay() -> Int { math.day(m.visibleStart) }

        // 1. Overview
        d.section("Week view: all-day lanes, 24h grid, current-time line")
        d.check(m.headerTitle == "September 2026", "header title")
        d.check(m.visibleDays.count == 7 && m.viewMode == .week, "seven day columns")
        d.check(m.layout.allDay.laneCount == 5, "five all-day lanes")
        d.check(m.layout.timedCount > 70, "timed events laid out (\(m.layout.timedCount))")
        d.check(m.todayIndex == 1, "today is column 2")
        d.frame(hold: 4)

        // 2. Navigation
        d.section("Navigate: J / K, arrows, T, option+T")
        d.key("j"); d.check(startDay() == 5 && math.month(m.visibleStart) == 10, "J goes to next week"); d.frame(hold: 1.2)
        d.key("k"); d.check(startDay() == 28, "K goes back"); d.frame(hold: 0.8)
        d.special("right"); d.check(startDay() == 5, "right arrow next week"); d.frame(hold: 0.8)
        d.special("left"); d.check(startDay() == 28, "left arrow previous week"); d.frame(hold: 0.8)
        d.key("j"); d.key("j"); d.frame(hold: 0.6)
        d.key("t"); d.check(startDay() == 28 && m.todayIndex == 1, "T returns to today"); d.frame(hold: 1)
        d.section("Left-align today in view")
        d.key("t", opt: true); d.check(startDay() == 29 && m.leftAligned, "option+T left-aligns today"); d.frame(hold: 2.2)
        d.key("t"); d.check(!m.leftAligned && startDay() == 28, "T restores Monday week"); d.frame(hold: 0.6)

        // 3. Mini calendar
        d.section("Mini calendar: click a day, chevrons change month")
        m.stepMiniMonth(1); d.frame(hold: 1)
        d.check(m.math.month(m.miniMonth) == 10, "mini month chevron")
        m.stepMiniMonth(-1)
        m.go(to: day(10, 12)); d.check(startDay() == 12, "mini calendar click navigates"); d.frame(hold: 1.5)
        d.key("t")

        // 4. View modes
        d.section("Day / Week / Month views: D, W, M")
        d.key("d"); d.check(m.viewMode == .day && m.visibleDays.count == 1, "D day view"); d.frame(hold: 2)
        d.key("m"); d.check(m.viewMode == .month && m.monthEvents.count == 42, "M month view"); d.frame(hold: 2.5)
        d.key("j"); d.check(m.headerTitle == "October 2026", "month next"); d.frame(hold: 0.8)
        d.key("t")
        d.key("w"); d.check(m.viewMode == .week, "W week view"); d.frame(hold: 1)
        m.setMode(.custom(3)); d.check(m.visibleDays.count == 3, "custom 3-day view"); d.section("Custom 2-7 day views (view menu)"); d.frame(hold: 1.6)
        m.setMode(.week); d.frame()

        // 5. Panels
        d.section("Toggle sidebar (`) and right panel (cmd /)")
        d.key("`"); d.check(!m.sidebarVisible, "backtick hides sidebar"); d.frame(hold: 1.6)
        d.key("`"); d.check(m.sidebarVisible, "backtick shows sidebar"); d.frame(hold: 0.5)
        d.key("/", cmd: true); d.check(!m.rightPanelVisible, "cmd-/ hides right panel"); d.frame(hold: 1.4)
        d.key("/", cmd: true); d.check(m.rightPanelVisible, "cmd-/ shows right panel"); d.frame(hold: 0.6)

        // 6. Calendars
        d.section("Calendars: click a row to hide or show it")
        let before = m.layout.timedCount
        m.toggleCalendar(DemoData.tasks); d.check(m.layout.timedCount < before && m.hiddenCalendars.contains(DemoData.tasks), "hide Tasks calendar"); d.frame(hold: 2)
        m.toggleCalendar(DemoData.tasks); d.check(m.layout.timedCount == before, "show Tasks calendar again"); d.frame(hold: 0.6)
        m.toggleCalendar(DemoData.svcHolidays); d.frame(hold: 0.4); m.toggleCalendar(DemoData.svcHolidays)

        // 7. All-day collapse
        d.section("All-day area: collapse to one lane with +N more")
        m.allDayCollapsed = true; d.settle(); d.frame(hold: 2)
        d.check(m.layout.allDay.collapsed(maxLanes: 1).hiddenPerDay.contains { $0 > 0 }, "collapsed shows hidden counts")
        m.allDayCollapsed = false; d.frame(hold: 0.5)

        // 8. Select event (real click)
        d.section("Click an event: inspector opens")
        guard let politik = placed(m, "Politik", day: 2) else { d.check(false, "Politik exists"); return }
        d.click(grid: centerOf(d, politik))
        d.check(m.selectedEvent?.title == "Politik", "real click selects Politik")
        d.frame(hold: 3.5)

        // 9. Inspector
        d.section("Inspector: title, time, date, recurrence, location, calendar, reminder")
        d.click(grid: centerOf(d, politik), clickCount: 2)
        d.settle(6)
        d.type(" LF1")
        d.check(m.selectedEvent?.title.hasSuffix("LF1") == true, "typed into the focused title field (\(m.selectedEvent?.title ?? "nil"))")
        d.frame(hold: 1.5)
        d.special("esc")
        m.updateSelected { $0.title = "Politik" }
        let orig = m.selectedEvent!
        m.updateSelected { $0.location = "Raum 204\nHaus 2" }; d.check(m.selectedEvent?.location.hasPrefix("Raum") == true, "location write-through"); d.frame(hold: 1)
        m.updateSelected { $0.location = orig.location }
        m.updateSelected { $0.calendarID = DemoData.family }; d.check(m.selectedEvent?.calendarID == DemoData.family, "calendar picker write-through"); d.frame(hold: 1.2)
        m.updateSelected { $0.calendarID = DemoData.personal }
        m.updateSelected { $0.reminderMinutes = 15 }; d.check(m.selectedEvent?.reminderMinutes == 15, "reminder write-through"); d.frame(hold: 1)
        m.updateSelected { $0.reminderMinutes = 1 }
        m.updateSelected { $0.participants.append("max@example.com") }; d.check(m.selectedEvent?.participants.contains("max@example.com") == true, "participant added"); d.frame(hold: 1.2)
        m.updateSelected { $0.participants.removeAll() }
        let ev0 = m.selectedEvent!
        m.updateSelected { $0.isAllDay = true; $0.start = math.startOfDay($0.start); $0.end = math.addDays($0.start, 1) }
        d.check(m.selectedEvent?.isAllDay == true && m.layout.allDay.placements.count > 5, "all-day toggle moves event to all-day lane"); d.frame(hold: 1.6)
        m.updateSelected { $0.isAllDay = false; $0.start = ev0.start; $0.end = ev0.end }
        d.check(m.selectedEvent?.isAllDay == false, "all-day off restores timed event")
        d.section("Recurrence chevrons: previous / next occurrence")
        let s0 = m.selectedEvent!.start
        m.selectOccurrence(1); d.check(m.selectedEvent.map { math.daysBetween(s0, $0.start) } == 7, "next occurrence is +7 days"); d.frame(hold: 1.8)
        m.selectOccurrence(-1); d.check(m.selectedEvent?.start == s0, "previous occurrence"); d.frame(hold: 0.5)

        // 10. Delete recurring + undo
        d.section("Delete a recurring event: This event / All events, cmd Z undoes")
        let count = m.layout.timedCount
        d.special("delete")
        d.check({ if case .deleteRecurring = m.overlay { return true } else { return false } }(), "delete key asks about recurrence"); d.frame(hold: 2.5)
        if let e = m.selectedEvent { m.delete(e, span: .this) }
        d.check(m.layout.timedCount == count - 1, "This event removes one occurrence"); d.frame(hold: 1.4)
        d.key("z", cmd: true); d.check(m.layout.timedCount == count, "cmd-Z restores it"); d.frame(hold: 1.4)
        d.special("esc")

        // 11. Drag-create
        d.section("Drag on the empty grid to create an event (15 minute snap)")
        let created0 = m.layout.timedCount
        d.drag(from: d.gridPoint(day: 5, minute: 14 * 60 + 3), to: d.gridPoint(day: 5, minute: 15 * 60 + 40))
        let newEv = m.selectedEvent
        d.check(newEv != nil && m.fmt.time(newEv!.start) == "14:00" && m.fmt.time(newEv!.end) == "15:45", "drag-create snapped 14:00-15:45 (got \(newEv.map { m.fmt.timeRange($0.start, $0.end) } ?? "nil"))")
        d.check(m.layout.timedCount == created0 + 1, "created event appears in the grid")
        d.settle(6)
        d.type("Zahnarzt Kontrolle")
        d.check(m.selectedEvent?.title.hasSuffix("Kontrolle") == true, "title typed into inspector (\(m.selectedEvent?.title ?? "nil"))")
        d.frame(hold: 2)
        d.special("esc"); d.special("esc")

        // 12. Move + resize
        d.section("Drag an event to move it across days; drag the bottom edge to resize")
        guard let mine = m.layout.timed[5].first(where: { $0.event.title.hasSuffix("Kontrolle") }) else { d.check(false, "created event findable"); return }
        let eid = mine.event.id
        d.drag(from: d.gridPoint(day: 5, minute: 14 * 60 + 25), to: d.gridPoint(day: 6, minute: 11 * 60 + 25))
        d.check(m.event(id: eid).map { math.weekdayIndex($0.start) == 6 && m.fmt.time($0.start) == "11:00" } == true, "moved to Sunday 11:00 (got \(m.event(id: eid).map { m.fmt.timeRange($0.start, $0.end) } ?? "nil"))")
        if let moved = m.flatTimed.first(where: { $0.event.id == eid }) {
            let r = m.gridGeometry.rect(for: moved)
            d.drag(from: CGPoint(x: r.midX, y: r.maxY - 3), to: CGPoint(x: r.midX, y: r.maxY + 48))
            d.check(m.event(id: eid).map { m.fmt.time($0.end) == "13:45" } == true, "resized to 13:45 (got \(m.event(id: eid).map { m.fmt.time($0.end) } ?? "nil"))")
        }
        d.frame(hold: 1)
        d.section("Undo: cmd Z reverts resize, move and create")
        d.key("z", cmd: true); d.check(m.event(id: eid).map { m.fmt.time($0.end) == "12:45" } == true, "undo resize"); d.frame(hold: 1)
        d.key("z", cmd: true); d.check(m.event(id: eid).map { math.weekdayIndex($0.start) == 5 } == true, "undo move"); d.frame(hold: 1)
        d.key("z", cmd: true); d.check(m.layout.timedCount == created0, "undo create"); d.frame(hold: 1.2)

        // 13. C creates
        d.section("C: create at the next free half hour")
        d.key("c"); let c = m.selectedEvent
        d.check(c != nil && m.fmt.time(c!.start) == "03:00" && c!.durationMinutes == 60, "C creates 03:00 (\(c.map { m.fmt.time($0.start) } ?? "nil"))")
        d.frame(hold: 1.8)
        d.special("esc"); d.special("esc"); d.check(m.layout.timedCount == created0, "untitled draft discarded on deselect")

        // 14. Search
        d.section("Search events: cmd F, type, results grouped by date, Return opens")
        d.key("f", cmd: true); d.frame(hold: 0.6)
        d.type("mathe")
        d.check(!m.searchGroups.isEmpty && m.searchGroups.count > 3, "search groups (\(m.searchGroups.count))")
        d.frame(hold: 2.5)
        d.special("return")
        d.check(m.selectedEvent?.title == "Mathe", "Return opens the first result")
        d.frame(hold: 1.6)
        d.special("esc"); m.searchText = ""; d.key("t")

        // 15. Command menu
        d.section("Command menu: cmd K, fuzzy filter, arrows, Return")
        d.key("k", cmd: true); d.check(m.overlay == .command, "cmd-K opens command menu"); d.frame(hold: 2)
        d.special("down"); d.special("down"); d.special("down"); d.check(m.commandIndex == 3, "arrow down moves selection"); d.frame(hold: 1)
        d.type("mont")
        d.check(CommandRegistry.flat(m.commandSections).first?.id == .viewMonth, "fuzzy filter finds Month view")
        d.frame(hold: 1.2)
        d.special("return"); d.check(m.viewMode == .month && m.overlay == nil, "Return runs the command"); d.frame(hold: 1.5)
        d.key("w")

        // 16. Teammates
        d.section("Show teammate calendar: P, filter, Return overlays their events")
        d.key("p"); d.check(m.overlay == .teammate, "P opens teammate picker"); d.frame(hold: 2)
        d.type("max")
        d.check(m.filteredTeammates(m.teammateQuery).first?.name == "Max Mustermann", "filter finds Max")
        d.special("return")
        d.check(m.shownTeammates.count == 1 && m.overlayLayout.timedCount > 0, "overlay events shown"); d.frame(hold: 2.5)
        d.key("p"); d.type("malte"); d.special("return"); d.check(m.shownTeammates.count == 2, "second teammate"); d.frame(hold: 1.5)
        d.section("Meet with...: F focuses the sidebar field")
        d.key("f"); d.type("to", frames: false); d.check(!m.filteredTeammates(m.meetQuery).isEmpty, "meet field filters teammates"); d.frame(hold: 1.6)
        d.special("esc")
        m.shownTeammates.forEach { m.removeTeammate($0) }; d.check(m.overlayLayout.timedCount == 0, "teammates removed"); d.frame(hold: 0.5)

        // 17. Go to date
        d.section("Go to date: . then natural input")
        d.key("."); d.check(m.overlay == .goToDate, "period opens go to date"); d.frame(hold: 1)
        d.type("next friday")
        d.check(m.goToPreview.map { math.day($0) == 9 && math.month($0) == 10 } == true, "preview resolves next friday")
        d.frame(hold: 1.8)
        d.special("return"); d.check(m.overlay == nil && math.day(m.visibleStart) == 5 && math.month(m.visibleStart) == 10, "Return navigates"); d.frame(hold: 1.2)
        d.key("."); d.type("12.10."); d.special("return"); d.check(math.day(m.visibleStart) == 12, "German date format"); d.frame(hold: 0.8)
        d.key("t")

        // 18. Shortcuts sheet
        d.section("All keyboard shortcuts: ?")
        d.key("?"); d.check(m.overlay == .shortcuts, "? opens shortcuts sheet"); d.frame(hold: 3)
        d.special("esc"); d.check(m.overlay == nil, "esc closes it")

        // 19. Settings
        d.section("Settings: cmd comma")
        d.key(",", cmd: true); d.check(m.overlay == .settings, "cmd-, opens settings"); d.frame(hold: 2)
        m.settings.use24h = false; d.settle(); d.check(m.fmt.time(m.selectedEvent?.start ?? m.now) .contains("AM") || m.fmt.time(m.now).contains("AM"), "12-hour format applies"); d.frame(hold: 1.6)
        m.settings.use24h = true
        m.settings.appearance = .light; d.win.setDark(false); d.settle(8); d.frame(hold: 2)
        m.settings.appearance = .dark; d.win.setDark(true); d.settle(8)
        m.settings.showDeclined = false; d.settle(); d.check(!m.layout.timed[2].contains { $0.event.status == .declined }, "hide declined events"); d.frame(hold: 1.2)
        m.settings.showDeclined = true
        d.special("esc")

        // 20. Menu bar
        d.section("Menu bar calendar: live label and upcoming popover")
        let label = Upcoming.menuBarLabel(m.upcoming)
        d.check(label == "Mathe \u{00B7} in 12m", "menu bar label: \(label)")
        d.check(m.upcoming.sections.first?.title == "Today" && m.upcoming.sections.dropFirst().first?.title == "Tomorrow", "popover sections")
        let pop = OffscreenWindow(MenuBarPopover().environment(m).environment(\.colorScheme, .dark), size: CGSize(width: 455, height: 820), chrome: false)
        pop.settle(6)
        d.popover = pop.image(scale: 2); d.menuBarLabel = label
        d.frame(hold: 4)
        d.popover = nil; d.menuBarLabel = nil; pop.close()
        if let next = m.upcoming.next { m.open(event: next) }
        d.check(m.selectedEvent?.title == "Meal Prep", "clicking an upcoming row opens it in the main window"); d.frame(hold: 2)
        m.deselect(); m.goToToday()

        // 21. Light
        d.section("Light appearance")
        m.settings.appearance = .light; d.win.setDark(false); d.settle(8); d.frame(hold: 3)
        m.settings.appearance = .dark; d.win.setDark(true); d.settle(8)

        d.section("Calendr: native SwiftUI, EventKit + demo store")
        d.frame(hold: 2.5)
    }
}
