import SwiftUI
import AppKit

// Shared building blocks (design/mockup-v4 `.ds` controls): key hints, buttons, the one segmented control, empty-state art.

struct SFIcon: View {
    let name: String
    var size: CGFloat = 16
    var color: Color = Theme.haze
    var weight: Font.Weight = .regular
    var body: some View {
        Image(systemName: name).font(.system(size: size, weight: weight)).foregroundStyle(color)
    }
}

/// Hover is a neutral wash, press is a 0.94 scale; both 120 ms.
struct PressStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(Motion.fast, value: configuration.isPressed)
    }
}

/// `.ibtn`: 26 pt square with a 16 pt icon (panel, header), or 22 with a 14 pt icon (`small`: sidebar, rows); radius 6, fg2 glyph,
/// hover wash and fg. An SF Symbol at point size p is about 1.33 p tall, so the icon box of g points uses a symbol of 0.75 g.
struct IconButton: View {
    let name: String
    var small = false
    var color: Color = Theme.fg2
    var help: String?
    let action: () -> Void
    @State private var hover = false
    @Environment(\.hoverWash) private var wash
    var body: some View {
        let glyph = small ? Dim.iconGlyphSmall : Dim.iconGlyph, box = small ? Dim.iconButtonSmall : Dim.iconButton
        Button(action: action) {
            SFIcon(name: name, size: glyph * 0.75, color: hover ? Theme.fg : color)
                .frame(width: glyph, height: glyph)
                .frame(width: box, height: box)
                .background(RoundedRectangle(cornerRadius: Radius.small).fill(hover ? wash : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
        .help(help ?? "")
    }
}

/// The v11 `.ibtn` with one of the mockup's stroke icons: 26 pt square with a 16 pt glyph (header), or 22 with 14 (`small`:
/// sidebar), radius 6, fg3; hover (and `on`) is the hover wash with an fg1 glyph. `rail`: on the sidebar or the right column, whose
/// hover is `hoverRail`. `probe` names the control for the tours' forced hover.
struct ChromeIconButton: View {
    let icon: ChromeIcon.Name
    var small = false
    var on = false
    var rail = false
    var probe: String?
    var help: String = ""
    let action: () -> Void
    @State private var hover = false
    @Environment(\.hoverWash) private var wash
    var body: some View {
        let hot = hover || on || (probe != nil && HoverProbe.shared.target == probe)
        let glyph = small ? Dim.iconGlyphSmall : Dim.iconGlyph, box = small ? Dim.iconButtonSmall : Dim.iconButton
        Button(action: action) {
            ChromeIcon(name: icon, size: glyph, color: hot ? Theme.fg : Theme.fg3)
                .frame(width: box, height: box)
                .background(RoundedRectangle(cornerRadius: Radius.row).fill(hot ? (rail ? Theme.hoverRail : wash) : Color.clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hot)
        .help(help)
    }
}

/// One keycap (v12 keycaps, round 1: `design/mockup-v12-keycaps`): 16 pt tall, at least 16 wide, 4 pt sides, radius 4, the raised
/// fill with a 1 pt `capEdge`, the key in small / 400 fg3. On a filled button (`onAct`) it has no fill, its edge and glyph in the
/// button ink at 30 % and 62 %. One cap holds a whole shortcut ("⌘Z"); alternatives ("↑", "↓") are separate caps.
struct Keycap: View {
    let text: String
    var onAct = false
    /// The label colour of the filled button the cap sits on (Primary: onAct, Danger: onDanger).
    var ink: Color = Theme.onAct
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.mark)
        HStack(spacing: 1) {
            // Geist draws ↩ as a thin squiggle: the SF Symbol, at the cap's text size, reads as the Return key.
            ForEach(Array(Self.parts(text).enumerated()), id: \.offset) { _, p in
                if p == "\u{21A9}" { Image(systemName: "return").font(.system(size: TypeSize.small - 1, weight: .semibold)) }
                else { Text(p).font(.smallTab) }
            }
        }
        .foregroundStyle(onAct ? ink.opacity(0.62) : Theme.fg3)
        .padding(.horizontal, 4).frame(minWidth: 16, minHeight: 16, maxHeight: 16)
        .background(shape.fill(onAct ? Color.clear : Theme.bg2))
        .overlay(shape.strokeBorder(onAct ? ink.opacity(0.3) : Theme.capEdge, lineWidth: 1))
        .fixedSize()
    }
    /// The return glyph is drawn as a symbol, so a shortcut is split around it ("⌘↩" → "⌘", "↩").
    static func parts(_ s: String) -> [String] {
        var out: [String] = [], run = ""
        for ch in s { if ch == "\u{21A9}" { if !run.isEmpty { out.append(run); run = "" }; out.append("\u{21A9}") } else { run.append(ch) } }
        if !run.isEmpty { out.append(run) }
        return out
    }
}

/// One shortcut in one cap: the keys of a combination are joined ("⌘", "Z" → "⌘Z"). "or" splits alternatives.
struct Keycaps: View {
    let keys: [String]
    var onAct = false
    var ink: Color = Theme.onAct
    /// Between alternatives (and around "or").
    var spacing: CGFloat = 3
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(Self.groups(keys).enumerated()), id: \.offset) { i, g in
                if i > 0 { Text("or").font(.small).foregroundStyle(Theme.fg3) }
                Keycap(text: g, onAct: onAct, ink: ink)
            }
        }
    }
    static func glyph(_ k: String) -> String { k == "command" ? "\u{2318}" : k }
    static func groups(_ keys: [String]) -> [String] {
        keys.split(separator: "or").map { $0.map(glyph).joined() }
    }
}

/// The kinds of button (design/mockup-v21 round 1). One height (`Dim.button`, 26), radius 9, 12 pt sides, the same on every shade:
/// - primary: the ink fill (`act`, `onAct` 600). One per place: Save, Join, Send.
/// - secondary: the neutral button. Its fill, edge and hover come from the shade it sits on (`ShadeColors`), fg1 500.
/// - ghost: text only, fg2 500; on hover the shade's hover fill and fg1. Icon buttons are ghosts too.
/// - danger: the red fill with a white 600 label, only to confirm a delete.
/// Disabled: the label in fg4; Primary and Danger lose their fill for the shade's selected fill.
enum ButtonKind: Sendable { case primary, secondary, ghost, danger }

/// The face of a button of one kind: fill, edge, label colour, height and radius. `ButtonFace` draws it around any label.
struct ButtonColors {
    let fill, edge, ink: Color
    init(_ kind: ButtonKind, shade: Shade, hot: Bool, disabled: Bool = false) {
        let s = ShadeColors.of(shade)
        let label: Color
        switch kind {
        case .primary: fill = disabled ? s.selected : hot ? Theme.actHover : Theme.act; edge = .clear; label = Theme.onAct
        case .danger: fill = disabled ? s.selected : hot ? Theme.dangerHover : Theme.danger; edge = .clear; label = Theme.onDanger
        case .secondary: fill = hot ? s.secondaryHover : s.secondary; edge = s.secondaryEdge; label = Theme.fg
        case .ghost: fill = hot ? s.hover : .clear; edge = .clear; label = hot ? Theme.fg : Theme.fg2
        }
        ink = disabled ? Theme.fg4 : label
    }
    static func filled(_ k: ButtonKind) -> Bool { k == .primary || k == .danger }
}

struct ButtonFace: ViewModifier {
    let kind: ButtonKind
    var hot = false
    var disabled = false
    var fullWidth = false
    var height: CGFloat = Dim.button
    var padding: CGFloat = Space.m
    @Environment(\.shade) private var shade
    func body(content: Content) -> some View {
        let c = ButtonColors(kind, shade: shade, hot: hot && !disabled, disabled: disabled)
        content
            .foregroundStyle(c.ink)
            .padding(.horizontal, padding).frame(maxWidth: fullWidth ? .infinity : nil).frame(height: height)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(c.fill))
            .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(c.edge, lineWidth: 1))
            .contentShape(Rectangle())
    }
}

extension View {
    func buttonFace(_ kind: ButtonKind, hot: Bool = false, disabled: Bool = false, fullWidth: Bool = false, height: CGFloat = Dim.button) -> some View {
        modifier(ButtonFace(kind: kind, hot: hot, disabled: disabled, fullWidth: fullWidth, height: height))
    }
}

/// The one text button. `probe` names it for the tours' forced hover (`HoverProbe`); `anchor` for `tourAnchor`.
struct HButton: View {
    let title: String
    var kind = ButtonKind.secondary
    var icon: String?
    var keys: [String] = []
    var fullWidth = false
    var disabled = false
    var probe: String?
    var help = ""
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        let hot = hover || (probe != nil && HoverProbe.shared.target == probe)
        let filled = ButtonColors.filled(kind)
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { SFIcon(name: icon, size: 12, color: ButtonColors(kind, shade: .window, hot: hot, disabled: disabled).ink) }
                Text(title).font(filled ? .textSemibold : .textMedium).tracking(TypeTrack.text)
                if !keys.isEmpty { Keycaps(keys: keys, onAct: filled, ink: kind == .danger ? Theme.onDanger : Theme.onAct) }
            }
            .buttonFace(kind, hot: hot, disabled: disabled, fullWidth: fullWidth)
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .disabled(disabled)
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hot)
        .help(help)
    }
}

/// The old name of `HButton` (settings): plain is a Ghost, line a Secondary, fill a Primary. `quiet` is a disabled-looking Ghost.
struct TextButton: View {
    enum Kind { case plain, line, fill }
    let title: String
    var kind = Kind.line
    var icon: String?
    var keys: [String] = []
    var small = false
    var quiet = false
    var disabled = false
    let action: () -> Void
    var body: some View {
        HButton(title: title, kind: kind == .fill ? .primary : kind == .plain || quiet ? .ghost : .secondary, icon: icon, keys: keys, disabled: disabled, action: action)
    }
}

/// A Primary `HButton`.
struct PrimaryButton: View {
    let title: String
    var keys: [String] = []
    var small = false
    let action: () -> Void
    var body: some View { HButton(title: title, kind: .primary, keys: keys, action: action) }
}

/// A Secondary `HButton`.
struct SecondaryButton: View {
    let title: String
    var keys: [String] = []
    var small = false
    let action: () -> Void
    var body: some View { HButton(title: title, kind: .secondary, keys: keys, action: action) }
}

/// The one segmented control (Day / Week / Month, Going?, every settings choice), mockup-v11 `.segc`: a `surface` track, padding 2,
/// radius 8, 26 pt in all. Segments are 22 pt high, radius 6, 10 pt side padding. The selected one is fg1 500 on `raised` with a
/// 1 pt `segRing` edge (and a soft shadow in Paper); the others are fg2 400, and hover only turns their text fg1.
struct Segmented<T: Hashable>: View {
    let options: [(T, String)]
    let selection: T
    var minWidth: CGFloat = 0
    var enabled = true
    /// Optional tooltip per option (same order as `options`).
    var helps: [String] = []
    let onSelect: (T) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { i, o in
                SegmentButton(title: o.1, on: o.0 == selection, minWidth: minWidth, enabled: enabled) { onSelect(o.0) }
                    .help(i < helps.count ? helps[i] : "")
            }
        }
        .segmentedFrame()
        .animation(Motion.fast, value: selection)
    }
}

private extension View {
    /// The track of `Segmented`: padding 2 on `surface`, radius 8, no edge.
    func segmentedFrame() -> some View {
        padding(2)
            .background(RoundedRectangle(cornerRadius: Radius.control).fill(Theme.bg1))
            .fixedSize()
    }
}

/// Hover forced by the walkthrough driver: synthesized pointer events cannot reach SwiftUI's hover tracking offscreen, so the
/// v4 tours name the control the cursor rests on. Nil in the app.
@MainActor @Observable
final class HoverProbe {
    static let shared = HoverProbe()
    var target: String?
}

struct SegmentButton: View {
    let title: String
    let on: Bool
    var minWidth: CGFloat = 0
    var enabled = true
    let action: () -> Void
    @State private var hover = false
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let h = (hover || HoverProbe.shared.target == title) && enabled && !on
        Button { if enabled { action() } } label: {
            // `.segc button`: 12 / 400 fg2 (fg1 on hover, no fill). The selected segment is the today mark (mockup-v16 round 1):
            // a filled `act` pill with `onAct` text, 500. Disabled (`.segc.off`): fg4, the selected one fg3 with a hair2 edge.
            Text(title).font(on ? .textMedium : .text).tracking(TypeTrack.text)
                .foregroundStyle(!enabled ? (on ? Theme.fg3 : Theme.fg4) : on ? Theme.onAct : h ? Theme.fg : Theme.fg2)
                .padding(.horizontal, 10).frame(minWidth: minWidth, minHeight: Dim.segment, maxHeight: Dim.segment)
                .background(RoundedRectangle(cornerRadius: Radius.inner).fill(on && enabled ? Theme.act : Color.clear))
                .overlay(RoundedRectangle(cornerRadius: Radius.inner).strokeBorder(on && !enabled ? Theme.hair2 : Color.clear, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(Motion.fast, value: hover)
    }
}

struct Hairline: View {
    var color: Color = Theme.hair
    var body: some View { Rectangle().fill(color).frame(height: 1) }
}

// MARK: Empty-state art

/// 7-column hairline grid tile with an act ring; the glyph decides the variant.
struct EmptyArt: View {
    enum Kind { case lock, search, ring }
    let kind: Kind
    var size: CGFloat = 64
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28).fill(Theme.ink700)
            Canvas { ctx, sz in
                var p = Path()
                for i in 1..<7 { let x = sz.width * CGFloat(i) / 7; p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: sz.height)) }
                ctx.stroke(p, with: .color(Theme.hair), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28))
            RoundedRectangle(cornerRadius: size * 0.28).strokeBorder(Theme.hairStrong, lineWidth: 1)
            switch kind {
            case .lock:
                Circle().stroke(Theme.act, style: StrokeStyle(lineWidth: size * 0.045, dash: [size * 0.04, size * 0.07])).frame(width: size * 0.56, height: size * 0.56)
                SFIcon(name: "lock.fill", size: size * 0.24, color: Theme.actLift)
            case .search:
                Circle().strokeBorder(Theme.act, lineWidth: size * 0.05).frame(width: size * 0.56, height: size * 0.56)
                Rectangle().fill(Theme.act).frame(width: size * 0.36, height: size * 0.05).rotationEffect(.degrees(-45))
            case .ring:
                Circle().strokeBorder(Theme.act, lineWidth: size * 0.05).frame(width: size * 0.5, height: size * 0.5)
                Circle().fill(Theme.actLift).frame(width: size * 0.12, height: size * 0.12)
            }
        }
        .frame(width: size, height: size)
    }
}
