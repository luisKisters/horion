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
                .padding(.leading, 20).padding(.top, 4).padding(.bottom, -4)
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
        let height = CGFloat(rows) * 21 + 3
        HStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                IconButton(name: collapsed ? "chevron.up.chevron.down" : "chevron.up", size: 10, box: 16) { model.allDayCollapsed.toggle() }
                    .offset(x: 52, y: 3)
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
        .frame(height: height + 2)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

struct MonthView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let grid = model.monthGrid
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(Fmt.weekdayShort[(model.math.calendar.firstWeekday - 1 + i) % 7]).font(.ui(12)).foregroundStyle(Theme.t2).frame(maxWidth: .infinity)
                }
            }
            .frame(height: 26)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
            GeometryReader { geo in
                let cw = geo.size.width / 7, ch = geo.size.height / 6
                ZStack(alignment: .topLeading) {
                    ForEach(0..<42, id: \.self) { i in
                        let r = i / 7, c = i % 7
                        MonthCell(day: grid[r][c], events: model.monthEvents[i], size: CGSize(width: cw, height: ch), dark: scheme == .dark)
                            .offset(x: CGFloat(c) * cw, y: CGFloat(r) * ch)
                    }
                }
            }
        }
    }
}

struct MonthCell: View {
    @Environment(AppModel.self) private var model
    let day: Date
    let events: [CalendarEvent]
    let size: CGSize
    let dark: Bool

    var body: some View {
        let other = !model.math.isSameMonth(day, model.visibleStart)
        let today = model.math.isSameDay(day, model.now)
        let past = model.math.startOfDay(day) < model.math.startOfDay(model.now)
        let maxChips = max(1, Int((size.height - 28) / 19))
        let shown = events.count > maxChips ? maxChips - 1 : events.count
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Spacer()
                Text("\(model.math.day(day))").font(.ui(12)).foregroundStyle(today ? .white : (other ? Theme.t3 : Theme.t1))
                    .frame(minWidth: 20, minHeight: 18).padding(.horizontal, 3)
                    .background(RoundedRectangle(cornerRadius: 5).fill(today ? Theme.red : Color.clear))
            }.frame(height: 20)
            ForEach(Array(events.prefix(shown)), id: \.id) { e in
                MonthChip(e: e, dark: dark, past: past).onTapGesture { model.select(eventID: e.id); model.rightPanelVisible = true }
            }
            if events.count > shown {
                Text("+\(events.count - shown) more").font(.ui(11)).foregroundStyle(Theme.t2).padding(.leading, 4).padding(.top, 1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 5).padding(.top, 4)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.line).frame(width: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { model.go(to: day); model.setMode(.day) }
        .onTapGesture { model.selectedSlot = model.math.date(on: day, minutes: 9 * 60) }
    }
}

struct MonthChip: View {
    @Environment(AppModel.self) private var model
    let e: CalendarEvent
    let dark: Bool
    let past: Bool
    var body: some View {
        let st = model.style(for: e, dark: dark, now: model.now, selected: model.selectedEventID == e.id, faded: false, overlapping: false)
        let pal = st.palette
        let declined = e.status == .declined
        HStack(spacing: 0) {
            Text(e.title.isEmpty ? "(No title)" : e.title).font(.ui(11)).strikethrough(declined)
                .foregroundStyle(declined ? Color(hex: "#f2d3cc") : (past ? pal.pastTitle : pal.title)).lineLimit(1)
            if !e.isAllDay { Text(model.fmt.time(e.start)).font(.mono(11)).foregroundStyle(pal.time).padding(.leading, 3) }
            Spacer(minLength: 0)
        }
        .padding(.leading, 8).frame(height: 17)
        .background(declined ? Color.clear : pal.fill)
        .overlay(alignment: .leading) { if !declined { Rectangle().fill(past ? pal.pastBar : pal.bar).frame(width: e.kind == .task ? 4 : 3) } }
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay { if declined { RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.declinedRed, style: StrokeStyle(lineWidth: 1, dash: [3, 2])) } }
        .brightness(st.selected ? 0.13 : 0)
    }
}
