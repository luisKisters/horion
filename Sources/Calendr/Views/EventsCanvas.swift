import SwiftUI
import AppKit
import CoreText
import CalendrKit

/// Draws every timed event of the visible range in one Canvas with CoreGraphics/CoreText. A week has 300+ events; a SwiftUI view per
/// event costs ~0.6 ms of graph work each on navigation and `GraphicsContext.resolve(Text)` ~50 us per string. Here a cached CTLine
/// draws in ~5 us. Hit testing is done by the model (`AppModel.hitTest`), so nothing here needs to be a view.
struct EventsCanvas: View {
    let events: [PlacedEvent]
    let geometry: GridGeometry
    let dark: Bool
    let now: Date
    let selectedID: String?
    let movingID: String?
    let preview: AppModel.DragPreview?
    let fmt: Fmt
    let styles: (CalendarEvent, Bool, Bool, Bool, Bool) -> EventStyle     // (event, dark, selected, faded, overlapping)
    let ghost: (EventPalette, String, String)?

    var body: some View {
        let g = geometry
        Canvas(opaque: false, rendersAsynchronously: false) { ctx, size in
            let t0 = CFAbsoluteTimeGetCurrent(); defer { if ProcessInfo.processInfo.environment["CALENDR_PROF"] != nil { print(String(format: "canvas %.1f ms (%d events)", (CFAbsoluteTimeGetCurrent() - t0) * 1000, events.count)) } }
            ctx.withCGContext { cg in
                for p in events {
                    let e = p.event
                    let rect = g.rect(for: p)
                    let style = styles(e, dark, e.id == selectedID, e.id == movingID, p.placement.columns > 1)
                    EventPainter.draw(cg, p: p, rect: rect, style: style, fmt: fmt)
                }
                if let pv = preview, let (pal, title, range) = ghost {
                    let y = CGFloat(g.yPos(pv.startMinute))
                    let h = max(11, CGFloat(g.yPos(pv.endMinute)) - y - 3)
                    let rect = CGRect(x: CGFloat(pv.dayIndex) * CGFloat(g.dayWidth) + 1, y: y, width: CGFloat(g.dayWidth) - 13, height: h)
                    EventPainter.drawGhost(cg, rect: rect, palette: pal, title: title, range: range)
                }
            }
        }
        .frame(width: CGFloat(g.dayWidth) * CGFloat(g.dayCount), height: CGFloat(g.totalHeight))
        .allowsHitTesting(false)
    }
}

/// Cached CoreText lines. Colors come from the graphics context, so one line serves every appearance and state.
@MainActor
enum TextCache {
    enum Kind: Int { case title, time, pill, pillTime, mini, dow, header, badge, label11, chipTime, dayNum }
    struct Key: Hashable { var text: String; var kind: Int }
    private static var lines: [Key: (CTLine, CGFloat, CGFloat, CGFloat)] = [:]   // line, width, ascent, descent
    private static var frames: [Key: [(CTLine, CGFloat)]] = [:]

    static func font(_ k: Kind) -> CTFont {
        switch k {
        case .title: return NSFont.systemFont(ofSize: 11.3, weight: .medium)
        case .time: return NSFont.monospacedDigitSystemFont(ofSize: 10.2, weight: .regular)
        case .pill: return NSFont.systemFont(ofSize: 10.8, weight: .medium)
        case .pillTime: return NSFont.monospacedDigitSystemFont(ofSize: 10.8, weight: .regular)
        case .mini: return NSFont.systemFont(ofSize: 13, weight: .regular)
        case .dow: return NSFont.systemFont(ofSize: 12, weight: .regular)
        case .header: return NSFont.systemFont(ofSize: 14, weight: .regular)
        case .badge: return NSFont.systemFont(ofSize: 13.5, weight: .regular)
        case .label11: return NSFont.systemFont(ofSize: 11, weight: .regular)
        case .chipTime: return NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        case .dayNum: return NSFont.systemFont(ofSize: 12, weight: .regular)
        }
    }

    static func line(_ text: String, _ kind: Kind) -> (line: CTLine, width: CGFloat, ascent: CGFloat, descent: CGFloat) {
        let key = Key(text: text, kind: kind.rawValue)
        if let hit = lines[key] { return (hit.0, hit.1, hit.2, hit.3) }
        let attrs: [NSAttributedString.Key: Any] = [.font: font(kind), NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true]
        let l = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
        var asc: CGFloat = 0, desc: CGFloat = 0, lead: CGFloat = 0
        let w = CGFloat(CTLineGetTypographicBounds(l, &asc, &desc, &lead))
        if lines.count > 6000 { lines.removeAll() }
        lines[key] = (l, w, asc, desc)
        return (l, w, asc, desc)
    }
}

enum EventPainter {
    /// Draws `line` with its line box top at `top` (CSS-style half leading inside `box` height).
    @MainActor
    static func text(_ cg: CGContext, _ s: String, _ kind: TextCache.Kind, x: CGFloat, top: CGFloat, box: CGFloat = 14, color: CGColor, strike: Bool = false) -> CGFloat {
        let l = TextCache.line(s, kind)
        let baseline = top + (box - (l.ascent + l.descent)) / 2 + l.ascent
        cg.saveGState()
        cg.setFillColor(color)
        cg.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        cg.textPosition = CGPoint(x: x, y: baseline)
        CTLineDraw(l.line, cg)
        if strike {
            cg.setStrokeColor(color); cg.setLineWidth(1)
            let y = baseline - l.ascent * 0.32
            cg.move(to: CGPoint(x: x, y: y)); cg.addLine(to: CGPoint(x: x + l.width, y: y)); cg.strokePath()
        }
        cg.restoreGState()
        return l.width
    }

    /// Like `text` but ends with an ellipsis when wider than `maxWidth` (returns the drawn width).
    @MainActor
    static func truncated(_ cg: CGContext, _ s: String, _ kind: TextCache.Kind, x: CGFloat, top: CGFloat, box: CGFloat = 14, color: CGColor, maxWidth: CGFloat) -> CGFloat {
        let l = TextCache.line(s, kind)
        if l.width <= maxWidth { return text(cg, s, kind, x: x, top: top, box: box, color: color) }
        let token = TextCache.line("\u{2026}", kind).line
        guard let cut = CTLineCreateTruncatedLine(l.line, Double(max(1, maxWidth)), .end, token) else { return 0 }
        let baseline = top + (box - (l.ascent + l.descent)) / 2 + l.ascent
        cg.saveGState()
        cg.setFillColor(color)
        cg.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        cg.textPosition = CGPoint(x: x, y: baseline)
        CTLineDraw(cut, cg)
        cg.restoreGState()
        return CGFloat(CTLineGetTypographicBounds(cut, nil, nil, nil))
    }

    /// Wraps `s` to at most `maxLines` lines of `lineHeight` inside `width`, returns the number of lines drawn.
    @MainActor
    static func wrapped(_ cg: CGContext, _ s: String, x: CGFloat, top: CGFloat, width: CGFloat, maxLines: Int, lineHeight: CGFloat, color: CGColor) -> Int {
        let l = TextCache.line(s, .title)
        if l.width <= width { _ = text(cg, s, .title, x: x, top: top, box: lineHeight, color: color); return 1 }
        // Break at the last space that fits; the second line is clipped by the event shape.
        let attr = NSAttributedString(string: s, attributes: [.font: TextCache.font(.title), NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true])
        let ts = CTTypesetterCreateWithAttributedString(attr)
        var start = 0
        var n = 0
        let len = (s as NSString).length
        while start < len && n < maxLines {
            let count = CTTypesetterSuggestLineBreak(ts, start, Double(width))
            let line = CTTypesetterCreateLine(ts, CFRange(location: start, length: max(1, count)))
            var asc: CGFloat = 0, desc: CGFloat = 0, lead: CGFloat = 0
            _ = CTLineGetTypographicBounds(line, &asc, &desc, &lead)
            let baseline = top + CGFloat(n) * lineHeight + (lineHeight - (asc + desc)) / 2 + asc
            cg.saveGState()
            cg.setFillColor(color)
            cg.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
            cg.textPosition = CGPoint(x: x, y: baseline)
            CTLineDraw(line, cg)
            cg.restoreGState()
            start += max(1, count)
            n += 1
        }
        return max(1, n)
    }

    static func roundedPath(_ r: CGRect, _ radius: CGFloat) -> CGPath {
        CGPath(roundedRect: r, cornerWidth: min(radius, r.height / 2), cornerHeight: min(radius, r.height / 2), transform: nil)
    }

    @MainActor
    static func draw(_ cg: CGContext, p: PlacedEvent, rect r: CGRect, style: EventStyle, fmt: Fmt) {
        let e = p.event
        let pal = style.palette
        let title = e.title.isEmpty ? "(No title)" : e.title
        cg.saveGState()
        defer { cg.restoreGState() }
        if style.faded { cg.setAlpha(0.35) }
        if e.kind == .task { pill(cg, rect: r, style: style, title: title, time: fmt.time(minutes: p.startMinute)); return }
        let range = "\(fmt.time(minutes: p.startMinute))\u{2013}\(fmt.time(minutes: p.endMinute))"
        if e.status == .declined { declined(cg, rect: r, title: title, range: range, time: fmt.time(minutes: p.startMinute)); return }

        let shape = roundedPath(r, 6)
        cg.addPath(shape); cg.setFillColor(pal.fillRGB.cg); cg.fillPath()
        cg.saveGState()
        cg.addPath(shape); cg.clip()
        let barColor = (style.past ? pal.pastBarRGB : pal.barRGB).cg
        if e.status == .tentative { stripes(cg, CGRect(x: r.minX, y: r.minY, width: 3, height: r.height), color: barColor) }
        else { cg.setFillColor(barColor); cg.fill(CGRect(x: r.minX, y: r.minY, width: 3, height: r.height)) }
        var textX = r.minX + 8.5
        if let b = style.secondaryBarCG {
            cg.setFillColor(b); cg.fill(CGRect(x: r.minX + 3, y: r.minY, width: 3, height: r.height))
            textX = r.minX + 12
        }
        let titleColor = (style.past ? pal.pastTitleRGB : pal.titleRGB).cg
        let timeColor = (style.past ? pal.pastTitleRGB : pal.timeRGB).cg
        let textW = r.maxX - 4 - textX
        if r.height >= 40 {
            let lines = wrapped(cg, title, x: textX, top: r.minY + 3, width: max(1, textW), maxLines: 2, lineHeight: 14, color: titleColor)
            _ = text(cg, range, .time, x: textX, top: r.minY + 3 + CGFloat(lines) * 14, color: timeColor)
        } else {
            let top = r.minY + max(0, (r.height - 14) / 2)
            let w = text(cg, title, .title, x: textX, top: top, color: titleColor)
            _ = text(cg, fmt.time(minutes: p.startMinute), .time, x: textX + w + 6, top: top, color: timeColor)
        }
        cg.restoreGState()
        if style.selected { selection(cg, shape) }
    }

    static func selection(_ cg: CGContext, _ shape: CGPath) {
        cg.addPath(shape); cg.setFillColor(CGColor(gray: 1, alpha: 0.13)); cg.fillPath()
        cg.addPath(shape); cg.setStrokeColor(CGColor(gray: 1, alpha: 0.28)); cg.setLineWidth(1); cg.strokePath()
    }

    static func stripes(_ cg: CGContext, _ r: CGRect, color: CGColor) {
        cg.saveGState()
        cg.clip(to: r)
        cg.setStrokeColor(color); cg.setLineWidth(2.8)
        var x = r.minX - r.height
        while x < r.maxX + r.height {
            cg.move(to: CGPoint(x: x, y: r.maxY)); cg.addLine(to: CGPoint(x: x + r.height, y: r.minY))
            x += 4 * 1.4142
        }
        cg.strokePath()
        cg.restoreGState()
    }

    @MainActor
    static func pill(_ cg: CGContext, rect r: CGRect, style: EventStyle, title: String, time: String) {
        let pal = style.palette
        let radius: CGFloat = r.height > 14 ? 6 : 5
        let shape = roundedPath(r, radius)
        if style.overlapping {
            cg.addPath(roundedPath(r.insetBy(dx: -1, dy: -1), radius + 1)); cg.setFillColor(style.isDark ? CGColor(srgbRed: 0.098, green: 0.098, blue: 0.098, alpha: 1) : CGColor(gray: 1, alpha: 1)); cg.fillPath()
        }
        cg.addPath(shape); cg.setFillColor(pal.fillRGB.cg); cg.fillPath()
        cg.saveGState()
        cg.addPath(shape); cg.clip()
        cg.setFillColor((style.past ? pal.pastBarRGB : pal.barRGB).cg)
        cg.fill(CGRect(x: r.minX, y: r.minY, width: 4.5, height: r.height))
        let top = r.minY + (r.height > 14 ? 3 : (r.height - 13) / 2)
        let w = text(cg, title, .pill, x: r.minX + 8, top: top, box: 13, color: (style.past ? pal.pastTitleRGB : pal.titleRGB).cg)
        _ = text(cg, time, .pillTime, x: r.minX + 8 + w + 4, top: top, box: 13, color: (style.past ? pal.pastTitleRGB : pal.timeRGB).cg)
        cg.restoreGState()
        if style.selected { selection(cg, shape) }
    }

    @MainActor
    static func declined(_ cg: CGContext, rect r: CGRect, title: String, range: String, time: String) {
        let shape = roundedPath(r.insetBy(dx: 0.5, dy: 0.5), 6)
        cg.saveGState()
        cg.addPath(shape); cg.setStrokeColor(CGColor(srgbRed: 0.878, green: 0.282, blue: 0.227, alpha: 1)); cg.setLineWidth(1); cg.setLineDash(phase: 0, lengths: [4, 3]); cg.strokePath()
        cg.restoreGState()
        cg.saveGState()
        cg.addPath(roundedPath(r, 6)); cg.clip()
        let tcol = CGColor(srgbRed: 0.949, green: 0.827, blue: 0.8, alpha: 1), mcol = CGColor(srgbRed: 0.784, green: 0.467, blue: 0.416, alpha: 1)
        if r.height >= 40 {
            _ = text(cg, title, .title, x: r.minX + 8.5, top: r.minY + 3, color: tcol, strike: true)
            _ = text(cg, range, .time, x: r.minX + 8.5, top: r.minY + 17, color: mcol, strike: true)
        } else {
            let top = r.minY + max(0, (r.height - 14) / 2)
            let w = text(cg, title, .title, x: r.minX + 8.5, top: top, color: tcol, strike: true)
            _ = text(cg, time, .time, x: r.minX + 8.5 + w + 6, top: top, color: mcol, strike: true)
        }
        cg.restoreGState()
    }

    @MainActor
    static func drawGhost(_ cg: CGContext, rect r: CGRect, palette pal: EventPalette, title: String, range: String) {
        cg.saveGState()
        defer { cg.restoreGState() }
        let shape = roundedPath(r, 6)
        cg.addPath(shape); cg.setFillColor(pal.fillRGB.cg.copy(alpha: 0.95) ?? pal.fillRGB.cg); cg.fillPath()
        cg.addPath(shape); cg.clip()
        cg.setFillColor(pal.barRGB.cg); cg.fill(CGRect(x: r.minX, y: r.minY, width: 3, height: r.height))
        _ = text(cg, title, .title, x: r.minX + 8.5, top: r.minY + 3, color: pal.titleRGB.cg)
        _ = text(cg, range, .time, x: r.minX + 8.5, top: r.minY + 17, color: pal.timeRGB.cg)
    }
}

extension EventStyle {
    var secondaryBarCG: CGColor? { secondaryBarRGB?.cg }
}
