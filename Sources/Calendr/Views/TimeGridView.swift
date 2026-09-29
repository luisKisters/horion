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
                ctx.draw(t, at: CGPoint(x: x0 - 6, y: CGFloat(h) * hourH - 0.5), anchor: .trailing)
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
                    EventsLayer(g: g, dark: scheme == .dark).offset(x: Theme.gutterWidth)
                    TeammateLayer(g: g).offset(x: Theme.gutterWidth)
                    NowMarker(g: g, y: nowY).offset(x: Theme.gutterWidth)
                    GridGestureLayer(g: g).offset(x: Theme.gutterWidth)
                }
                .frame(width: geo.size.width, height: Theme.hourHeight * 24, alignment: .topLeading)
            }
            .scrollPosition($scroll)
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { model.gridViewport = $0 }
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { _ in model.gridGeometry = g }
            .onAppear {
                model.gridGeometry = g
                model.gridScrollY = CGFloat(model.settings.firstVisibleHour) * Theme.hourHeight - 3
                scroll = ScrollPosition(y: model.gridScrollY)
            }
            .onChange(of: model.scrollToHourTick) { _, _ in
                model.gridScrollY = CGFloat(model.settings.firstVisibleHour) * Theme.hourHeight - 3
                scroll = ScrollPosition(y: model.gridScrollY)
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
        AbsoluteLayout(size: CGSize(width: CGFloat(g.dayWidth) * CGFloat(g.dayCount), height: CGFloat(g.totalHeight))) {
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
        let moving = model.dragPreview.flatMap { $0.kind == .create ? nil : $0.eventID }
        var ghost: (EventPalette, String, String)?
        if let d = model.dragPreview {
            let e = model.event(id: d.eventID)
            let pal = Palettes.palette(barHex: e.map { model.calendarColorHex(of: $0) } ?? model.defaultCalendarHex, fillHex: e?.colorHex, dark: dark)
            ghost = (pal, e.map { $0.title.isEmpty ? "(No title)" : $0.title } ?? "(No title)", "\(model.fmt.time(minutes: d.startMinute))\u{2013}\(model.fmt.time(minutes: d.endMinute))")
        }
        let m = model
        return EventsCanvas(events: model.flatTimed, geometry: g, dark: dark, now: model.now, selectedID: model.selectedEventID, movingID: moving,
                            preview: model.dragPreview, fmt: model.fmt,
                            styles: { e, dark, sel, faded, overl in
                                var s = m.style(for: e, dark: dark, now: m.now, selected: sel, faded: faded, overlapping: overl)
                                s.isDark = dark
                                return s
                            }, ghost: ghost)
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
