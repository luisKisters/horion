import SwiftUI
import CalendrKit

struct SFIcon: View {
    let name: String
    var size: CGFloat = 16
    var color: Color = Theme.t2
    var weight: Font.Weight = .regular
    var body: some View {
        Image(systemName: name).font(.system(size: size, weight: weight)).foregroundStyle(color)
    }
}

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @FocusState private var meetFocused: Bool

    var body: some View {
        @Bindable var m = model
        ZStack(alignment: .topLeading) {
            Theme.side
            // Titlebar icons (traffic lights are the real window buttons).
            IconButton(name: "sidebar.left", size: 15) { model.toggleSidebar() }.position(x: 93, y: 20)
            IconButton(name: "magnifyingglass", size: 14) { model.handle(.focusSearch) }.position(x: 185, y: 20)
            IconButton(name: "square.and.pencil", size: 14) { model.handle(.createEvent) }.position(x: 215, y: 20)

            // Mini calendar
            IconButton(name: "chevron.up", size: 12, box: 16) { model.stepMiniMonth(-1) }.position(x: 188, y: 63)
            IconButton(name: "chevron.down", size: 12, box: 16) { model.stepMiniMonth(1) }.position(x: 214, y: 63)
            MiniCalendar().frame(width: 226).offset(x: 6, y: 76)

            // Scheduling
            SidebarRow(icon: "link", title: "Scheduling", trailingIcon: "eye") { model.perform(.oneOffLink) }.offset(y: 283)

            // Meet with field
            HStack(spacing: 0) {
                SFIcon(name: "person", size: 14, color: Color(hex: "#7a7a7a")).frame(width: 18).padding(.leading, 14).padding(.trailing, 8)
                TextField("", text: $m.meetQuery, prompt: Text("Meet with\u{2026}").foregroundStyle(Theme.placeholder))
                    .textFieldStyle(.plain).font(.ui(13)).foregroundStyle(Theme.t1)
                    .focused($meetFocused)
                    .onSubmit { pickMeet() }
            }
            .frame(width: 224, height: 30, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.field))
            .offset(x: 6, y: 323)
            .onChange(of: model.focusMeetTick) { _, _ in meetFocused = true }
            .onChange(of: model.blurTick) { _, _ in meetFocused = false }

            // Calendars
            ScrollView(.vertical, showsIndicators: false) {
                CalendarList()
                    .padding(.top, model.shownTeammates.isEmpty ? 0 : 0)
                    .padding(.bottom, 56)
            }
            .frame(width: Theme.sidebarWidth, alignment: .topLeading)
            .padding(.top, 353)

            if !model.meetQuery.trimmingCharacters(in: .whitespaces).isEmpty { MeetResults().offset(x: 6, y: 357) }
            if model.notionPopoverVisible { NotionPopover().offset(x: 30, y: 640) }

            // Help button
            VStack { Spacer(); HStack {
                ZStack(alignment: .topTrailing) {
                    SFIcon(name: "questionmark.circle", size: 16).frame(width: 30, height: 30)
                    Circle().fill(Theme.red).frame(width: 6, height: 6).offset(x: -3, y: 3)
                }
                .frame(width: 30, height: 30)
                .background(Circle().fill(Theme.side))
                .contentShape(Rectangle())
                .onTapGesture { model.handle(.showShortcuts) }
                .padding(.leading, 8).padding(.bottom, 9)
                Spacer() } }
        }
        .frame(width: Theme.sidebarWidth)
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.border).frame(width: 1) }
    }

    private func pickMeet() {
        let list = model.filteredTeammates(model.meetQuery)
        guard !list.isEmpty else { return }
        model.showTeammate(list[min(model.meetIndex, list.count - 1)])
        model.meetQuery = ""
    }
}

struct IconButton: View {
    let name: String
    var size: CGFloat = 16
    var box: CGFloat = 22
    var color: Color = Theme.t2
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            SFIcon(name: name, size: size, color: hover ? Theme.t1 : color).frame(width: box, height: box)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

struct SidebarRow: View {
    let icon: String
    let title: String
    var trailingIcon: String?
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                (hover ? Theme.hover : Color.clear)
                SFIcon(name: icon, size: 15).frame(width: 18).padding(.leading, 14)
                Text(title).font(.ui(13.3)).foregroundStyle(Theme.t1).padding(.leading, 40)
                if let t = trailingIcon {
                    HStack { Spacer(); SFIcon(name: t, size: 13).padding(.trailing, 15) }
                }
            }
            .frame(width: Theme.sidebarWidth - 1, height: 29)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

/// Weekday row + six week rows in one Canvas with cached CoreText lines (42 changing Text views cost ~10 ms per month change);
/// a single tap gesture picks the cell.
struct MiniCalendar: View {
    @Environment(AppModel.self) private var model
    static let width: CGFloat = 226
    static let rowHeight: CGFloat = 28
    static let headerHeight: CGFloat = 24

    var body: some View {
        let grid = model.math.monthGrid(for: model.miniMonth)
        let first = model.math.calendar.firstWeekday
        let bandStart = model.viewMode == .month ? nil : model.math.startOfWeek(model.visibleStart)
        let miniMonth = model.miniMonth
        let now = model.now
        let math = model.math
        Canvas { ctx, size in
            ctx.withCGContext { cg in
                let colW = size.width / 7
                let dowColor = NSColor(Theme.miniDow).cgColor
                for i in 0..<7 {
                    let s = String(Fmt.weekdayShort[(first - 1 + i) % 7].prefix(2))
                    let w = TextCache.line(s, .dow).width
                    _ = EventPainter.text(cg, s, .dow, x: (CGFloat(i) + 0.5) * colW - w / 2, top: 0, box: Self.headerHeight, color: dowColor)
                }
                let normal = NSColor(Theme.miniDay).cgColor, dim = NSColor(Theme.miniOther).cgColor, dimBand = CGColor(srgbRed: 0.396, green: 0.396, blue: 0.396, alpha: 1)
                for r in 0..<6 {
                    let y = Self.headerHeight + CGFloat(r) * Self.rowHeight
                    let isBand = bandStart.map { math.isSameDay($0, grid[r][0]) } ?? false
                    if isBand {
                        cg.addPath(EventPainter.roundedPath(CGRect(x: 0, y: y, width: size.width, height: Self.rowHeight), 8))
                        cg.setFillColor(NSColor(Theme.band).cgColor); cg.fillPath()
                    }
                    for c in 0..<7 {
                        let d = grid[r][c]
                        let today = math.isSameDay(d, now)
                        let cx = (CGFloat(c) + 0.5) * colW
                        if today {
                            cg.addPath(EventPainter.roundedPath(CGRect(x: cx - 13.5, y: y + 2.5, width: 27, height: 23), 6))
                            cg.setFillColor(NSColor(Theme.red).cgColor); cg.fillPath()
                        }
                        let other = !math.isSameMonth(d, miniMonth)
                        let color = today ? CGColor(gray: 1, alpha: 1) : other ? (isBand ? dimBand : dim) : normal
                        let s = "\(math.day(d))"
                        let w = TextCache.line(s, .mini).width
                        _ = EventPainter.text(cg, s, .mini, x: cx - w / 2, top: y, box: Self.rowHeight, color: color)
                    }
                }
            }
        }
        .frame(width: Self.width, height: Self.headerHeight + 6 * Self.rowHeight)
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { p in
            let r = Int((p.y - Self.headerHeight) / Self.rowHeight), c = Int(p.x / (Self.width / 7))
            if (0..<6).contains(r), (0..<7).contains(c) { model.go(to: grid[r][c]) }
        }
    }
}

struct CalendarList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !model.shownTeammates.isEmpty {
                AccountLabel(text: "Teammates").padding(.top, 12)
                ForEach(model.shownTeammates) { t in
                    TeammateRow(t: t)
                }
            }
            ForEach(model.store.accounts) { acc in
                AccountLabel(text: acc.name)
                ForEach(acc.calendars) { c in CalendarRow(cal: c) }
            }
            SidebarLinkRow(icon: "plus", title: "Add calendar account") { model.addCalendarAccount() }.padding(.top, 11)
            Rectangle().fill(Theme.sep).frame(height: 1).padding(.top, 15)
            SidebarLinkRow(icon: "tablecells.badge.ellipsis", title: "Add Notion database") { model.perform(.addNotionDatabase) }.padding(.top, 16)
            Rectangle().fill(Theme.sep).frame(height: 1).padding(.top, 15)
            SidebarRow(icon: "n.square", title: "Notion") { model.notionPopoverVisible.toggle() }.padding(.top, 13)
        }
        .frame(width: Theme.sidebarWidth - 1, alignment: .leading)
    }
}

struct AccountLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.ui(12.5)).foregroundStyle(Theme.miniDow).lineLimit(1).truncationMode(.tail)
            .frame(height: 18, alignment: .leading)
            .padding(.leading, 14).padding(.trailing, 12)
            .padding(.top, 16.5).padding(.bottom, 4.5)
    }
}

struct SidebarLinkRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                (hover ? Theme.hover : Color.clear)
                SFIcon(name: icon, size: 15).frame(width: 18).padding(.leading, 14)
                Text(title).font(.ui(13.3)).foregroundStyle(Color(hex: "#7a7a7a")).padding(.leading, 40)
            }
            .frame(width: Theme.sidebarWidth - 1, height: 29).contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { hover = $0 }
    }
}

struct CalendarRow: View {
    @Environment(AppModel.self) private var model
    let cal: CalendarInfo
    @State private var hover = false
    var body: some View {
        let off = model.hiddenCalendars.contains(cal.id)
        let color = Color(hex: cal.colorHex)
        Button { model.toggleCalendar(cal.id) } label: {
            ZStack(alignment: .leading) {
                (hover ? Theme.hover : Color.clear)
                Group {
                    if cal.isDefault {
                        RoundedRectangle(cornerRadius: 5.5).strokeBorder(color, lineWidth: 1.5).frame(width: 18, height: 18)
                            .overlay(RoundedRectangle(cornerRadius: 3).fill(color).padding(3.5))
                            .padding(.leading, 14)
                    } else {
                        RoundedRectangle(cornerRadius: 4).fill(color).frame(width: 13, height: 13)
                            .overlay { if cal.icon == .feed { Image(systemName: "dot.radiowaves.up.forward").font(.system(size: 7, weight: .bold)).foregroundStyle(Color(hex: "#202020")) } }
                            .padding(.leading, 16.5)
                    }
                }.opacity(off ? 0.35 : 1)
                HStack(spacing: 0) {
                    Text(cal.title).font(.ui(13.3)).foregroundStyle(off ? Color(hex: "#4d4d4d") : Theme.t1).lineLimit(1)
                    if cal.isDefault { Text("Default").font(.ui(13.3)).foregroundStyle(Theme.t2).padding(.leading, 6) }
                }.padding(.leading, 40).padding(.trailing, off ? 36 : 12)
                if off { HStack { Spacer(); SFIcon(name: "eye.slash", size: 13).padding(.trailing, 14) } }
            }
            .frame(width: Theme.sidebarWidth - 1, height: 29, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

struct TeammateRow: View {
    @Environment(AppModel.self) private var model
    let t: Teammate
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4).fill(Color(hex: model.teammateColor(t.email))).frame(width: 13, height: 13).padding(.leading, 16.5)
            Text(t.name).font(.ui(13.3)).foregroundStyle(Theme.t1).lineLimit(1).padding(.leading, 40).padding(.trailing, 36)
            HStack { Spacer(); IconButton(name: "xmark", size: 10, box: 16) { model.removeTeammate(t) }.padding(.trailing, 14) }
        }
        .frame(width: Theme.sidebarWidth - 1, height: 29, alignment: .leading)
    }
}

struct MeetResults: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let list = Array(model.filteredTeammates(model.meetQuery).prefix(6))
        VStack(alignment: .leading, spacing: 0) {
            if list.isEmpty { Text("No teammates found").font(.ui(13)).foregroundStyle(Theme.t2).padding(10) }
            ForEach(Array(list.enumerated()), id: \.element.id) { i, t in
                Button { model.showTeammate(t); model.meetQuery = "" } label: {
                    HStack(spacing: 6) {
                        Text(t.name).font(.ui(13)).foregroundStyle(Theme.t1).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10).frame(height: 28)
                    .background(RoundedRectangle(cornerRadius: 6).fill(i == model.meetIndex ? Theme.palSel : Color.clear))
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
        .padding(4)
        .frame(width: 224)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.pal))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.palBorder))
        .shadow(color: .black.opacity(0.45), radius: 14, y: 8)
    }
}

struct NotionPopover: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Notion is not connected").font(.ui(13, .medium)).foregroundStyle(Theme.t1)
            Text("Notion databases are not available in Calendr yet.").font(.ui(12)).foregroundStyle(Theme.t2).fixedSize(horizontal: false, vertical: true)
            Button("Not connected") { model.notionPopoverVisible = false }.buttonStyle(.plain).font(.ui(12)).foregroundStyle(Theme.ring).padding(.top, 4)
        }
        .padding(12).frame(width: 190, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.pal))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.palBorder))
        .shadow(color: .black.opacity(0.45), radius: 14, y: 8)
    }
}
