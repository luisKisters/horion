import SwiftUI
import CalendrKit

/// Diagonal stripes (135 degrees). Used for tentative bars and teammate overlay fills.
struct Stripes: View {
    var color: Color
    var on: CGFloat = 2
    var off: CGFloat = 2
    var body: some View {
        Canvas { ctx, size in
            let period = on + off
            var x = -size.height
            var path = Path()
            while x < size.width + size.height {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += period * 1.4142
            }
            ctx.stroke(path, with: .color(color), lineWidth: on * 1.4142)
        }
    }
}

struct EventStyle: Equatable {
    var palette: EventPalette
    var secondaryBarRGB: RGB?
    var secondaryBar: Color? { secondaryBarRGB?.color }
    var past: Bool
    var selected: Bool
    var faded: Bool
    var overlapping: Bool
    var isDark = true
}

struct TeammateCell: View, Equatable {
    let title: String
    let rect: CGRect
    let hue: Color
    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.bg
            Stripes(color: hue.opacity(0.2), on: 4, off: 4)
            Text(title).font(.ui(11.5)).foregroundStyle(hue).lineLimit(1).fixedSize().padding(.top, 2).padding(.leading, 6).padding(.trailing, 4)
        }
        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(hue, lineWidth: 1))
        .placed(rect)
    }
}

/// All-day chip / task pill in the all-day lanes and month chips.
struct AllDayChip: View, Equatable {
    let title: String
    let width: CGFloat
    let style: EventStyle
    let isTask: Bool
    let height: CGFloat

    var body: some View {
        let pal = style.palette
        ZStack(alignment: .leading) {
            Text(title).font(.ui(11.6)).foregroundStyle(style.past ? pal.pastTitle : pal.title).lineLimit(1).fixedSize()
                .padding(.leading, style.secondaryBar != nil ? 15 : 8).padding(.trailing, 4)
            HStack(spacing: 0) {
                Rectangle().fill(style.past ? pal.pastBar : pal.bar).frame(width: 3.5)
                if let b = style.secondaryBar { Rectangle().fill(b).frame(width: 3) }
                Spacer(minLength: 0)
            }
        }
        .frame(width: width, height: height, alignment: .leading)
        .background(pal.fill)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .brightness(style.selected ? 0.13 : 0)
        .overlay { if style.selected { RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.28), lineWidth: 1) } }
    }
}
