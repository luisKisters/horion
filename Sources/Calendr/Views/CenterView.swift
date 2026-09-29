import SwiftUI
import CalendrKit

struct CenterView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView().frame(height: Theme.toolbarHeight)
            Text(model.headerTitle)
                .font(.ui(22, .semibold)).foregroundStyle(Theme.t1)
                .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36, alignment: .leading)
                .padding(.leading, 20).padding(.top, 3).padding(.bottom, -3)
                .frame(height: 36, alignment: .topLeading)
            if model.viewMode == .month {
                MonthView()
            } else {
                DayHeaderView().frame(height: 26)
                AllDayView()
                TimeGridView()
            }
        }
        .background(Theme.bg)
    }
}

struct ToolbarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Avatar().frame(width: 24, height: 24)
            Spacer().frame(width: 13)
            ViewMenu().frame(width: 76, height: 30)
            Spacer().frame(width: 6)
            Button { model.goToToday() } label: {
                Text("Today").font(.ui(13)).foregroundStyle(Theme.t1)
                    .frame(width: 60, height: 30)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.btn))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.btnBorder))
            }.buttonStyle(.plain)
            Spacer().frame(width: 16)
            IconButton(name: "chevron.left", size: 13, box: 22) { model.previous() }
            Spacer().frame(width: 10)
            IconButton(name: "chevron.right", size: 13, box: 22) { model.next() }
            Spacer().frame(width: model.rightPanelVisible ? 14 : 12)
            if !model.rightPanelVisible {
                IconButton(name: "sidebar.right", size: 15, box: 22) { model.toggleRightPanel() }
                Spacer().frame(width: 4)
            }
        }
        .padding(.top, 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
    }
}

struct Avatar: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.white)
            Circle().fill(Color(hex: "#c98f6b")).frame(width: 12.5, height: 12.5).offset(y: -1.5)
            Capsule().fill(Color(hex: "#3b2418")).frame(width: 12, height: 6).offset(y: -6)
            Ellipse().fill(Color(hex: "#1a1a1a")).frame(width: 18, height: 10).offset(y: 10)
        }
        .clipShape(Circle())
    }
}

struct ViewMenu: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        Menu {
            Button("Day") { model.setMode(.day) }
            Button("Week") { model.setMode(.week) }
            Button("Month") { model.setMode(.month) }
            Divider()
            Menu("Custom") {
                ForEach(2...6, id: \.self) { n in Button("\(n) days") { model.setMode(.custom(n)) } }
            }
        } label: {
            HStack(spacing: 6) {
                Text(model.viewMode.title).font(.ui(13)).foregroundStyle(Theme.t1)
                SFIcon(name: "chevron.down", size: 9, weight: .semibold)
            }
            .frame(width: 76, height: 30)
            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.btn))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.btnBorder))
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

struct DayHeaderView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                IconButton(name: "plus", size: 11, box: 14) { model.secondTimeZoneVisible.toggle() }.offset(x: 12, y: 5)
                Text(model.fmt.gmtLabel(model.now)).font(.ui(11)).foregroundStyle(Theme.t2)
                    .frame(width: Theme.gutterWidth - 6, height: 26, alignment: .trailing)
            }
            .frame(width: Theme.gutterWidth, height: 26, alignment: .topLeading)
            ForEach(Array(model.visibleDays.enumerated()), id: \.offset) { _, d in
                let today = model.math.isSameDay(d, model.now)
                HStack(spacing: 5) {
                    Text(model.fmt.weekdayShort(d) + (today ? "" : " \(model.math.day(d))"))
                        .font(.ui(14)).foregroundStyle(today ? Theme.t1 : Theme.t2)
                    if today {
                        Text("\(model.math.day(d))").font(.ui(13.5)).foregroundStyle(.white)
                            .padding(.horizontal, 5).frame(height: 17)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Theme.red))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 24, alignment: .center)
                .frame(height: 26, alignment: .top)
            }
        }
        .overlay(alignment: .topTrailing) { SFIcon(name: "plus", size: 11).padding(.trailing, 6).padding(.top, 5) }
    }
}

struct AllDayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let n = max(1, model.visibleDays.count)
        let lanes = model.layout.allDay.laneCount
        let collapsed = model.allDayCollapsed
        let collapsedResult = model.layout.allDay.collapsed(maxLanes: 1)
        let rows = max(1, collapsed ? (lanes > 1 ? 2 : 1) : lanes)
        let total = CGFloat(rows) * 21 + 3          // box height incl. both 1pt borders (108 for five lanes)
        let height = total - 2
        HStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Button { model.allDayCollapsed.toggle() } label: {
                    ChevronPair(outward: collapsed).stroke(Theme.t2, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)).frame(width: 16, height: 16)
                }.buttonStyle(.plain).offset(x: 52, y: 3)
            }.frame(width: Theme.gutterWidth, height: height, alignment: .topLeading)
            GeometryReader { geo in
                let dw = geo.size.width / CGFloat(n)
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        ForEach(0..<n, id: \.self) { _ in
                            Rectangle().fill(Color.clear).frame(maxWidth: .infinity)
                                .overlay(alignment: .leading) { Rectangle().fill(Theme.line).frame(width: 1) }
                        }
                    }
                    let placements = collapsed ? collapsedResult.visible : model.layout.allDay.placements
                    ForEach(placements, id: \.id) { p in
                        if let e = model.layout.allDayEvents[p.id] {
                            let x = CGFloat(p.firstDay) * dw + 1
                            let w = CGFloat(p.span) * dw - 13
                            AllDayChip(title: e.title.isEmpty ? "(No title)" : e.title, width: max(8, w),
                                       style: model.style(for: e, dark: scheme == .dark, now: model.now, selected: model.selectedEventID == e.id, faded: false, overlapping: false),
                                       isTask: e.kind == .task, height: 19)
                                .offset(x: x, y: 2 + CGFloat(p.lane) * 21)
                                .onTapGesture { model.select(eventID: e.id, focusTitle: NSApp.currentEvent?.clickCount == 2) }
                        }
                    }
                    if collapsed {
                        ForEach(0..<n, id: \.self) { i in
                            if collapsedResult.hiddenPerDay[i] > 0 {
                                Text("+\(collapsedResult.hiddenPerDay[i]) more").font(.ui(11.5)).foregroundStyle(Theme.t2)
                                    .offset(x: CGFloat(i) * dw + 9, y: 2 + 21)
                            }
                        }
                    }
                }
            }.frame(height: height)
        }
        .padding(.top, 1).padding(.bottom, 1)
        .frame(height: total)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

/// Layout of the month grid, shared by drawing and hit testing.
struct MonthGeometry {
    var size: CGSize
    var cellWidth: CGFloat { size.width / 7 }
    var cellHeight: CGFloat { size.height / 6 }
    static let chipHeight: CGFloat = 17
    static let chipPitch: CGFloat = 19
    static let headerHeight: CGFloat = 22        // day number row incl. top padding

    func cellRect(_ i: Int) -> CGRect { CGRect(x: CGFloat(i % 7) * cellWidth, y: CGFloat(i / 7) * cellHeight, width: cellWidth, height: cellHeight) }
    var maxChips: Int { max(1, Int((cellHeight - 28) / Self.chipPitch)) }
    func shownCount(_ n: Int) -> Int { n > maxChips ? maxChips - 1 : n }
    func chipRect(cell i: Int, index k: Int) -> CGRect {
        let c = cellRect(i)
        return CGRect(x: c.minX + 5, y: c.minY + 4 + Self.headerHeight + 2 + CGFloat(k) * Self.chipPitch, width: c.width - 10, height: Self.chipHeight)
    }
    func hit(_ p: CGPoint, counts: [Int]) -> (cell: Int, chip: Int?)? {
        guard p.x >= 0, p.y >= 0, p.x < size.width, p.y < size.height else { return nil }
        let i = min(41, Int(p.y / cellHeight) * 7 + Int(p.x / cellWidth))
        for k in 0..<shownCount(counts[i]) where chipRect(cell: i, index: k).contains(p) { return (i, k) }
        return (i, nil)
    }
}

/// The month grid is one Canvas (day numbers, chips, "+N more"); a tap gesture resolves cell/chip through `MonthGeometry`.
struct MonthView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(Fmt.weekdayShort[(model.math.calendar.firstWeekday - 1 + i) % 7]).font(.ui(12)).foregroundStyle(Theme.t2).frame(maxWidth: .infinity)
                }
            }
            .frame(height: 26)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
            GeometryReader { geo in
                MonthCanvas(size: geo.size, dark: scheme == .dark)
            }
        }
    }
}

struct MonthCanvas: View {
    @Environment(AppModel.self) private var model
    let size: CGSize
    let dark: Bool

    var body: some View {
        let geo = MonthGeometry(size: size)
        let grid = model.monthGrid
        let events = model.monthEvents
        let math = model.math
        let now = model.now
        let today = math.startOfDay(now)
        let visibleStart = model.visibleStart
        let selected = model.selectedEventID
        let fmt = model.fmt
        let m = model
        let counts = events.map(\.count)
        return Canvas { ctx, sz in
            ctx.withCGContext { cg in
                MonthPainter.draw(cg, geo: geo, dark: dark, grid: grid, events: events, math: math, today: today, visibleStart: visibleStart,
                                  selected: selected, fmt: fmt, style: { e in m.style(for: e, dark: dark, now: now, selected: false, faded: false, overlapping: false) })
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, coordinateSpace: .local) { p in
            if let h = geo.hit(p, counts: counts), h.chip == nil { model.go(to: grid[h.cell / 7][h.cell % 7]); model.setMode(.day) }
        }
        .onTapGesture(coordinateSpace: .local) { p in
            guard let h = geo.hit(p, counts: counts) else { return }
            if let k = h.chip { model.select(eventID: events[h.cell][k].id) }
            else { model.deselect(); model.selectedSlot = math.date(on: grid[h.cell / 7][h.cell % 7], minutes: 9 * 60) }
        }
    }
}

enum MonthPainter {
    @MainActor
    static func draw(_ cg: CGContext, geo: MonthGeometry, dark: Bool, grid: [[Date]], events: [[CalendarEvent]], math: CalendarMath, today: Date,
                     visibleStart: Date, selected: String?, fmt: Fmt, style: (CalendarEvent) -> EventStyle) {
        func c(_ d: String, _ l: String) -> CGColor { RGB(hex: dark ? d : l).cg }
        let line = c("#222222", "#ebebeb"), t1 = c("#d4d4d4", "#2a2a2a"), t3 = c("#5a5a5a", "#b4b4b4"), t2 = c("#7f7f7f", "#8a8a8a")
        let red = c("#df6057", "#e5534b")
        cg.setStrokeColor(line); cg.setLineWidth(1)
        for i in 0..<42 {
            let r = geo.cellRect(i)
            cg.move(to: CGPoint(x: r.maxX - 0.5, y: r.minY)); cg.addLine(to: CGPoint(x: r.maxX - 0.5, y: r.maxY))
            cg.move(to: CGPoint(x: r.minX, y: r.maxY - 0.5)); cg.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 0.5))
        }
        cg.strokePath()
        for i in 0..<42 {
            let d = grid[i / 7][i % 7]
            let r = geo.cellRect(i)
            let other = !math.isSameMonth(d, visibleStart)
            let isToday = math.isSameDay(d, today)
            let past = math.startOfDay(d) < today
            // day number, right aligned in a 20pt pill
            let s = "\(math.day(d))"
            let w = TextCache.line(s, .dayNum).width
            let pillW = max(20, w + 6)
            let px = r.maxX - 5 - pillW
            if isToday {
                cg.addPath(EventPainter.roundedPath(CGRect(x: px, y: r.minY + 5, width: pillW, height: 18), 5)); cg.setFillColor(red); cg.fillPath()
            }
            _ = EventPainter.text(cg, s, .dayNum, x: px + (pillW - w) / 2, top: r.minY + 4, box: 20, color: isToday ? CGColor(gray: 1, alpha: 1) : (other ? t3 : t1))
            let list = events[i]
            let shown = geo.shownCount(list.count)
            for k in 0..<shown {
                let e = list[k]
                let cr = geo.chipRect(cell: i, index: k)
                let st = style(e)
                let pal = st.palette
                cg.saveGState()
                if past { cg.setAlpha(0.7) }
                let shape = EventPainter.roundedPath(cr, 5)
                if e.status == .declined {
                    cg.addPath(EventPainter.roundedPath(cr.insetBy(dx: 0.5, dy: 0.5), 5)); cg.setStrokeColor(CGColor(srgbRed: 0.878, green: 0.282, blue: 0.227, alpha: 1))
                    cg.setLineWidth(1); cg.setLineDash(phase: 0, lengths: [3, 2]); cg.strokePath(); cg.setLineDash(phase: 0, lengths: [])
                } else {
                    cg.addPath(shape); cg.setFillColor(pal.fillRGB.cg); cg.fillPath()
                }
                cg.addPath(shape); cg.clip()
                if e.status != .declined {
                    cg.setFillColor(pal.barRGB.cg); cg.fill(CGRect(x: cr.minX, y: cr.minY, width: e.kind == .task ? 4 : 3, height: cr.height))
                }
                let titleColor = e.status == .declined ? CGColor(srgbRed: 0.949, green: 0.827, blue: 0.8, alpha: 1) : pal.titleRGB.cg
                let title = e.title.isEmpty ? "(No title)" : e.title
                let timeText = e.isAllDay ? "" : fmt.time(e.start)
                let timeW = timeText.isEmpty ? 0 : TextCache.line(timeText, .chipTime).width + 3
                let avail = cr.width - 8 - 4 - timeW
                let tw: CGFloat
                if e.status == .declined { tw = EventPainter.text(cg, title, .label11, x: cr.minX + 8, top: cr.minY + 1.5, box: 14, color: titleColor, strike: true) }
                else { tw = EventPainter.truncated(cg, title, .label11, x: cr.minX + 8, top: cr.minY + 1.5, box: 14, color: titleColor, maxWidth: avail) }
                if !timeText.isEmpty { _ = EventPainter.text(cg, timeText, .chipTime, x: cr.minX + 8 + tw + 3, top: cr.minY + 1.5, box: 14, color: pal.timeRGB.cg) }
                cg.restoreGState()
                if e.id == selected {
                    cg.addPath(shape); cg.setFillColor(CGColor(gray: 1, alpha: 0.13)); cg.fillPath()
                    cg.addPath(shape); cg.setStrokeColor(CGColor(gray: 1, alpha: 0.28)); cg.setLineWidth(1); cg.strokePath()
                }
            }
            if list.count > shown {
                let cr = geo.chipRect(cell: i, index: shown)
                _ = EventPainter.text(cg, "+\(list.count - shown) more", .label11, x: cr.minX + 4, top: cr.minY + 1.5, box: 14, color: t2)
            }
        }
    }
}

/// The all-day collapse/expand glyph from the mockup: two chevrons pointing at each other (collapse) or apart (expand).
struct ChevronPair: Shape {
    var outward: Bool
    func path(in r: CGRect) -> Path {
        var p = Path()
        let s = r.width / 24
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * s, y: r.minY + y * s) }
        if outward {   // expand: top chevron up, bottom chevron down
            p.move(to: pt(8, 9)); p.addLine(to: pt(12, 5)); p.addLine(to: pt(16, 9))
            p.move(to: pt(8, 15)); p.addLine(to: pt(12, 19)); p.addLine(to: pt(16, 15))
        } else {       // collapse: top chevron down, bottom chevron up
            p.move(to: pt(8, 4.5)); p.addLine(to: pt(12, 8.5)); p.addLine(to: pt(16, 4.5))
            p.move(to: pt(8, 19.5)); p.addLine(to: pt(12, 15.5)); p.addLine(to: pt(16, 19.5))
        }
        return p
    }
}
