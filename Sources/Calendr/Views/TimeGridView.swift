import SwiftUI
import AppKit
import CalendrKit

/// Hour lines, column separators and hour labels: one Canvas.
struct GridBackground: View {
    let dayCount: Int
    let dayWidth: CGFloat
    let use24h: Bool
    let dark: Bool

    var body: some View {
        Canvas { ctx, size in
            let hourH = Theme.hourHeight
            let x0 = Theme.gutterWidth
            var lines = Path()
            for h in 0..<24 {
                let y = CGFloat(h) * hourH + 0.5
                lines.move(to: CGPoint(x: x0, y: y)); lines.addLine(to: CGPoint(x: size.width, y: y))
            }
            ctx.stroke(lines, with: .color(Theme.hline), lineWidth: 1)
            var cols = Path()
            for d in 0..<dayCount {
                let x = x0 + CGFloat(d) * dayWidth + 0.5
                cols.move(to: CGPoint(x: x, y: 0)); cols.addLine(to: CGPoint(x: x, y: size.height))
            }
            ctx.stroke(cols, with: .color(Theme.line), lineWidth: 1)
            for h in 1..<24 {
                let label = use24h ? String(format: "%02d:00", h) : "\((h % 12) == 0 ? 12 : h % 12) \(h < 12 ? "AM" : "PM")"
                let t = ctx.resolve(Text(label).font(.mono(11)).foregroundColor(Theme.t2))
                ctx.draw(t, at: CGPoint(x: x0 - 6, y: CGFloat(h) * hourH + 0.5), anchor: .trailing)
            }
        }
        .frame(height: Theme.hourHeight * 24)
        .drawingGroup(opaque: false)
    }
}

struct TimeGridView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var scroll = ScrollPosition(y: 0)
    @State private var didInitialScroll = false

    var body: some View {
        let n = max(1, model.visibleDays.count)
        GeometryReader { geo in
            let dw = max(1, (geo.size.width - Theme.gutterWidth) / CGFloat(n))
            let g = GridGeometry(dayWidth: Double(dw), hourHeight: Double(Theme.hourHeight), dayCount: n)
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    GridBackground(dayCount: n, dayWidth: dw, use24h: model.settings.use24h, dark: scheme == .dark)
                        .frame(width: geo.size.width)
                    if model.todayIndex != nil {
                        Rectangle().fill(Theme.red.opacity(0.4)).frame(width: dw * CGFloat(n), height: 1)
                            .offset(x: Theme.gutterWidth, y: nowY)
                    }
                    SlotHighlight(g: g).offset(x: Theme.gutterWidth)
                    TeammateLayer(g: g).offset(x: Theme.gutterWidth)
                    EventsLayer(g: g, dark: scheme == .dark).offset(x: Theme.gutterWidth)
                    NowMarker(g: g, y: nowY).offset(x: Theme.gutterWidth)
                    GridGestureLayer(g: g).offset(x: Theme.gutterWidth)
                }
                .frame(width: geo.size.width, height: Theme.hourHeight * 24, alignment: .topLeading)
            }
            .scrollPosition($scroll)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { _ in model.gridGeometry = g }
            .onAppear {
                model.gridGeometry = g
                scroll = ScrollPosition(y: CGFloat(model.settings.firstVisibleHour) * Theme.hourHeight - 3)
            }
            .onChange(of: model.scrollToHourTick) { _, _ in
                scroll = ScrollPosition(y: CGFloat(model.settings.firstVisibleHour) * Theme.hourHeight - 3)
            }
            .onChange(of: n) { _, _ in model.gridGeometry = g }
        }
    }

    private var nowY: CGFloat { CGFloat(model.math.minutesSinceMidnight(model.now)) / 60 * Theme.hourHeight }
}

private struct NowMarker: View {
    @Environment(AppModel.self) private var model
    let g: GridGeometry
    let y: CGFloat
    var body: some View {
        if let i = model.todayIndex {
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Theme.red).frame(width: CGFloat(g.dayWidth) + 1, height: 1)
                Circle().fill(Theme.red).frame(width: 8, height: 8).offset(x: -4, y: -3.5)
            }
            .offset(x: CGFloat(i) * CGFloat(g.dayWidth) - 1, y: y)
            .allowsHitTesting(false)
        }
    }
}

private struct SlotHighlight: View {
    @Environment(AppModel.self) private var model
    let g: GridGeometry
    var body: some View {
        if let slot = model.selectedSlot, let d = model.visibleDays.firstIndex(where: { model.math.isSameDay($0, slot) }) {
            Rectangle().fill(Color.white.opacity(0.06))
                .frame(width: CGFloat(g.dayWidth) - 13, height: CGFloat(g.hourHeight) / 2 - 1)
                .offset(x: CGFloat(d) * CGFloat(g.dayWidth) + 1, y: CGFloat(g.yPos(model.math.minutesSinceMidnight(slot))))
                .allowsHitTesting(false)
        }
    }
}

private struct TeammateLayer: View {
    @Environment(AppModel.self) private var model
    let g: GridGeometry
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(model.flatOverlay) { p in
                let bandX = CGFloat(g.dayWidth) * 0.52
                let bandW = CGFloat(g.dayWidth) * 0.48 - 12
                let x = CGFloat(p.dayIndex) * CGFloat(g.dayWidth) + bandX + CGFloat(p.placement.left) * bandW
                let y = CGFloat(g.yPos(p.startMinute))
                let h = max(14, CGFloat(g.yPos(p.endMinute)) - y - 3)
                TeammateCell(title: p.event.title, rect: CGRect(x: x, y: y, width: max(8, CGFloat(p.placement.width) * bandW), height: h), hue: Color(hex: model.teammateColor(p.event.ownerEmail)))
                    .equatable()
            }
        }
        .allowsHitTesting(false)
    }
}

private struct EventsLayer: View {
    @Environment(AppModel.self) private var model
    let g: GridGeometry
    let dark: Bool

    var body: some View {
        let now = model.now
        let fmt = model.fmt
        ZStack(alignment: .topLeading) {
            ForEach(model.flatTimed) { p in
                let e = p.event
                let moving = model.dragPreview?.kind != .create && model.dragPreview?.eventID == e.id
                EventCell(p: p, rect: g.rect(for: p),
                          style: model.style(for: e, dark: dark, now: now, selected: model.selectedEventID == e.id, faded: moving, overlapping: p.placement.columns > 1),
                          timeText: fmt.time(minutes: p.startMinute), rangeText: fmt.timeRange(e.start, e.end),
                          title: e.title.isEmpty ? "(No title)" : e.title)
                    .equatable()
            }
            if let d = model.dragPreview { DragGhost(d: d, g: g, dark: dark) }
        }
        .allowsHitTesting(false)
    }
}

private struct DragGhost: View {
    @Environment(AppModel.self) private var model
    let d: AppModel.DragPreview
    let g: GridGeometry
    let dark: Bool
    var body: some View {
        let e = model.event(id: d.eventID)
        let hex = e.map { model.hexColor(of: $0) } ?? model.defaultCalendarHex
        let pal = Palettes.palette(barHex: e.map { model.calendarColorHex(of: $0) } ?? hex, fillHex: e?.colorHex, dark: dark)
        let y = CGFloat(g.yPos(d.startMinute))
        let h = CGFloat(g.yPos(d.endMinute)) - y - 3
        let fmt = model.fmt
        ZStack(alignment: .topLeading) {
            pal.fill.opacity(0.95)
            Rectangle().fill(pal.bar).frame(width: 3)
            VStack(alignment: .leading, spacing: 0) {
                Text(e?.title.isEmpty == false ? e!.title : "(No title)").font(.ui(11.3, .medium)).foregroundStyle(pal.title)
                Text("\(fmt.time(minutes: d.startMinute))\u{2013}\(fmt.time(minutes: d.endMinute))").font(.mono(10.2)).foregroundStyle(pal.time)
            }.padding(.leading, 8.5).padding(.top, 3)
        }
        .frame(width: CGFloat(g.dayWidth) - 13, height: max(11, h), alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .offset(x: CGFloat(d.dayIndex) * CGFloat(g.dayWidth) + 1, y: y)
    }
}

/// Single gesture surface for the whole grid. The gesture only forwards points to the model; the walkthrough
/// drives the very same model entry points.
private struct GridGestureLayer: View {
    @Environment(AppModel.self) private var model
    let g: GridGeometry
    @State private var down = false

    var body: some View {
        Color.clear
            .frame(width: CGFloat(g.dayWidth) * CGFloat(g.dayCount), height: CGFloat(g.totalHeight))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { v in
                    if !down {
                        down = true
                        model.gridGeometry = g
                        model.gridMouseDown(v.startLocation, clickCount: NSApp.currentEvent?.clickCount ?? 1)
                    }
                    model.gridMouseDragged(v.location)
                }
                .onEnded { v in
                    down = false
                    model.gridMouseUp(v.location)
                })
            .onContinuousHover { phase in
                switch phase {
                case .active(let p):
                    if case .event(_, _, _, _, true)? = model.hitTest(p) { NSCursor.resizeUpDown.set() } else { NSCursor.arrow.set() }
                case .ended: NSCursor.arrow.set()
                }
            }
    }
}
