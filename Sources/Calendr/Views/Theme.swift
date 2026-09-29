import SwiftUI
import AppKit

// Values come from design/mockup/index.html (the design source, sampled from the reference screenshots).

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        let v = UInt64(h, radix: 16) ?? 0
        self.init(.sRGB, red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255, opacity: 1)
    }
    /// Dynamic color following the effective appearance (dark first).
    static func dyn(_ dark: String, _ light: String) -> Color {
        Color(nsColor: NSColor(name: nil) { ap in
            let isDark = ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
    }
    static func dyn(_ dark: Color, _ light: Color) -> Color {
        Color(nsColor: NSColor(name: nil) { ap in
            NSColor(ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light)
        })
    }
}

enum Theme {
    static let bg = Color.dyn("#191919", "#ffffff")
    static let side = Color.dyn("#202020", "#f7f7f5")
    static let line = Color.dyn("#222222", "#ebebeb")
    static let hline = Color.dyn("#1f1f1f", "#f0f0f0")
    static let border = Color.dyn("#262626", "#e6e6e6")
    static let sep = Color.dyn("#2c2c2c", "#e9e9e9")
    static let t1 = Color.dyn("#d4d4d4", "#2a2a2a")
    static let t2 = Color.dyn("#7f7f7f", "#8a8a8a")
    static let t3 = Color.dyn("#5a5a5a", "#b4b4b4")
    static let hover = Color.dyn("#2b2b2b", "#ececea")
    static let chip = Color.dyn("#2b2b2b", "#eeeeec")
    static let chipText = Color.dyn("#a0a0a0", "#777777")
    static let btn = Color.dyn("#272727", "#f4f4f2")
    static let btnBorder = Color.dyn("#333333", "#e3e3e1")
    static let red = Color.dyn("#df6057", "#e5534b")
    static let pal = Color.dyn("#1f1f1f", "#ffffff")
    static let palBorder = Color.dyn("#2c2c2c", "#e3e3e1")
    static let palSel = Color.dyn("#2b2b2b", "#f1f1ef")
    static let palChip = Color.dyn("#363636", "#eeeeec")
    static let palFoot = Color.dyn("#202020", "#fafaf9")
    static let palFootText = Color.dyn("#848486", "#848486")
    static let band = Color.dyn("#2c2c2c", "#ebebe9")
    static let field = Color.dyn("#2b2b2b", "#efefed")
    static let placeholder = Color.dyn("#676767", "#a5a5a5")
    static let overlay = Color.dyn(Color.black.opacity(0.30), Color.black.opacity(0.18))
    static let ring = Color(hex: "#5c88e4")
    static let pop = Color.dyn("#1c1c1c", "#fbfbfa")
    static let popBorder = Color.dyn("#2e2e2e", "#e3e3e1")
    static let getCal = Color.dyn("#252525", "#f1f1ef")
    static let miniDow = Color.dyn("#838383", "#8a8a8a")
    static let miniDay = Color.dyn("#d5d5d5", "#333333")
    static let miniOther = Color.dyn("#5c5c5c", "#c0c0c0")
    static let declinedRed = Color(hex: "#e0483a")

    // Metrics
    static let hourHeight: CGFloat = 48
    static let gutterWidth: CGFloat = 71
    static let sidebarWidth: CGFloat = 238
    static let rightPanelWidth: CGFloat = 284
    static let toolbarHeight: CGFloat = 40
}

/// Colors for an event: fill and text come from the (possibly overridden) color, the bar from the calendar.
struct EventPalette: Equatable {
    var bar: Color, fill: Color, title: Color, time: Color, pastTitle: Color, pastBar: Color
}

enum Palettes {
    private struct Named { var bar: String; var dark: [String]; var light: [String] }   // fill, title, time, pastTitle, pastBar
    private static let named: [Named] = [
        Named(bar: "#5c88e4", dark: ["#38425d", "#eef3ff", "#8c9ecb", "#808595", "#415274"], light: ["#dde7fb", "#1e3a7d", "#5f7dbd", "#98a6c8", "#b6c8ef"]),
        Named(bar: "#80cf93", dark: ["#334837", "#def5e4", "#7bad85", "#7e9083", "#48604d"], light: ["#dcf0e1", "#1e5a30", "#4f8a62", "#93b39c", "#b4dcc0"]),
        Named(bar: "#f1c55d", dark: ["#4d4021", "#fefabb", "#b3985a", "#9a9066", "#6d5c2c"], light: ["#f8ecc6", "#5c4400", "#98772a", "#b7a56a", "#efd58a"]),
        Named(bar: "#8236dd", dark: ["#493962", "#fdf5fe", "#a795c4", "#8f8499", "#5a4a75"], light: ["#e6dbf6", "#41216e", "#7f5eb0", "#a493c0", "#c7aeea"]),
        Named(bar: "#ef8452", dark: ["#5a3a2b", "#ffe9df", "#c99276", "#9a8479", "#7a4f37"], light: ["#fbe3d8", "#6b2f12", "#a56a4f", "#c4a595", "#f5c2ac"]),
        Named(bar: "#69a9dd", dark: ["#2f4658", "#e6f3ff", "#86aacb", "#7c8f9e", "#3f6079"], light: ["#dcebf7", "#173d5c", "#5d86a8", "#93aabb", "#b6d3ec"]),
        Named(bar: "#bdbcbc", dark: ["#424242", "#ffffff", "#8a8a8a", "#848585", "#515050"], light: ["#e7e7e5", "#2c2c2c", "#8a8a8a", "#a6a6a6", "#c9c9c9"]),
    ]
    nonisolated(unsafe) private static var cache: [String: (Color, [Color])] = [:]

    private static func rgb(_ hex: String) -> (Double, Double, Double) {
        let v = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        return (Double((v >> 16) & 255) / 255, Double((v >> 8) & 255) / 255, Double(v & 255) / 255)
    }
    private static func mix(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ t: Double) -> Color {
        Color(.sRGB, red: a.0 + (b.0 - a.0) * t, green: a.1 + (b.1 - a.1) * t, blue: a.2 + (b.2 - a.2) * t, opacity: 1)
    }

    /// (bar, [fill, title, time, pastTitle, pastBar]) for a calendar hex.
    private static func resolve(_ hex: String, dark: Bool) -> (Color, [Color]) {
        let k = hex.lowercased() + (dark ? "|d" : "|l")
        if let c = cache[k] { return c }
        let t = rgb(hex)
        var best: (Named, Double)?
        for n in named {
            let r = rgb(n.bar)
            let d = pow(r.0 - t.0, 2) + pow(r.1 - t.1, 2) + pow(r.2 - t.2, 2)
            if best == nil || d < best!.1 { best = (n, d) }
        }
        let out: (Color, [Color])
        if let (n, d) = best, d < 0.02 {
            out = (Color(hex: hex), (dark ? n.dark : n.light).map { Color(hex: $0) })
        } else {
            let bg = dark ? (0.098, 0.098, 0.098) : (1.0, 1.0, 1.0)
            let white = (1.0, 1.0, 1.0), black = (0.0, 0.0, 0.0)
            out = (Color(hex: hex), dark
                ? [mix(bg, t, 0.28), mix(t, white, 0.85), mix(t, white, 0.3), mix((0.5, 0.5, 0.5), t, 0.2), mix(bg, t, 0.38)]
                : [mix(bg, t, 0.2), mix(t, black, 0.55), mix(t, black, 0.2), mix((0.7, 0.7, 0.7), t, 0.2), mix(bg, t, 0.4)])
        }
        cache[k] = out
        return out
    }

    static func palette(barHex: String, fillHex: String?, dark: Bool) -> EventPalette {
        let cal = resolve(barHex, dark: dark)
        let f = fillHex.map { resolve($0, dark: dark) } ?? cal
        return EventPalette(bar: cal.0, fill: f.1[0], title: f.1[1], time: f.1[2], pastTitle: f.1[3], pastBar: cal.1[4])
    }
    static let gray = { (dark: Bool) in palette(barHex: "#bdbcbc", fillHex: nil, dark: dark) }
}

extension Font {
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight).monospacedDigit() }
}
