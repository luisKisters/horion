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
    var secondaryBar: Color?
    var past: Bool
    var selected: Bool
    var faded: Bool
    var overlapping: Bool
}

/// One timed event in the grid. Equatable so unchanged events are not re-diffed on navigation.
struct EventCell: View, Equatable {
    let p: PlacedEvent
    let rect: CGRect
    let style: EventStyle
    let timeText: String
    let rangeText: String
    let title: String

    var body: some View {
        let e = p.event
        let content: some View = Group {
            if e.kind == .task { TaskPill(title: title, time: timeText, rect: rect, style: style) }
            else if e.status == .declined { DeclinedBlock(title: title, range: rangeText, time: timeText, rect: rect) }
            else { EventBlock(title: title, range: rangeText, time: timeText, rect: rect, style: style, tentative: e.status == .tentative) }
        }
        content
            .frame(width: rect.width, height: rect.height, alignment: .topLeading)
            .brightness(style.selected ? 0.13 : 0)
            .overlay {
                if style.selected { RoundedRectangle(cornerRadius: e.kind == .task ? 5 : 6).strokeBorder(Color.white.opacity(0.28), lineWidth: 1) }
            }
            .opacity(style.faded ? 0.35 : 1)
            .offset(x: rect.minX, y: rect.minY)
    }
}

struct EventBlock: View {
    let title: String, range: String, time: String
    let rect: CGRect
    let style: EventStyle
    let tentative: Bool

    var body: some View {
        let pal = style.palette
        let two = rect.height >= 40
        let leading: CGFloat = style.secondaryBar != nil ? 12 : 8.5
        ZStack(alignment: .topLeading) {
            Group {
                if two {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(title).font(.ui(11.3, .medium)).foregroundStyle(style.past ? pal.pastTitle : pal.title).lineLimit(2).frame(minHeight: 14, alignment: .topLeading)
                        Text(range).font(.mono(10.2)).foregroundStyle(style.past ? pal.pastTitle : pal.time).lineLimit(1).frame(height: 14, alignment: .topLeading)
                    }
                    .padding(.top, 3)
                } else {
                    (Text(title).font(.ui(11.3, .medium)).foregroundColor(style.past ? pal.pastTitle : pal.title)
                     + Text("  " + time).font(.mono(10.2)).foregroundColor(style.past ? pal.pastTitle : pal.time))
                        .lineLimit(1).fixedSize()
                        .frame(height: max(14, rect.height), alignment: .leading)
                }
            }
            .padding(.leading, leading).padding(.trailing, 4)
            HStack(spacing: 0) {
                Group {
                    if tentative { Stripes(color: style.past ? pal.pastBar : pal.bar).frame(width: 3) }
                    else { Rectangle().fill(style.past ? pal.pastBar : pal.bar).frame(width: 3) }
                }
                if let b = style.secondaryBar { Rectangle().fill(b).frame(width: 3) }
            }
        }
        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
        .background(pal.fill)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct DeclinedBlock: View {
    let title: String, range: String, time: String
    let rect: CGRect
    var body: some View {
        let two = rect.height >= 40
        Group {
            if two {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.ui(11.3, .medium)).strikethrough().foregroundStyle(Color(hex: "#f2d3cc")).lineLimit(1).frame(height: 14, alignment: .topLeading)
                    Text(range).font(.mono(10.2)).strikethrough().foregroundStyle(Color(hex: "#c8776a")).lineLimit(1).frame(height: 14, alignment: .topLeading)
                }.padding(.top, 3)
            } else {
                (Text(title).font(.ui(11.3, .medium)).strikethrough().foregroundColor(Color(hex: "#f2d3cc"))
                 + Text("  " + time).font(.mono(10.2)).strikethrough().foregroundColor(Color(hex: "#c8776a"))).lineLimit(1)
            }
        }
        .padding(.leading, 8.5).padding(.trailing, 4)
        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.declinedRed, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }
}

struct TaskPill: View {
    let title: String, time: String
    let rect: CGRect
    let style: EventStyle
    var body: some View {
        let pal = style.palette
        let radius: CGFloat = rect.height > 14 ? 6 : 5
        ZStack(alignment: .topLeading) {
            if style.overlapping {
                RoundedRectangle(cornerRadius: radius + 1).fill(Theme.bg).padding(-1)
            }
            RoundedRectangle(cornerRadius: radius).fill(pal.fill)
            (Text(title).font(.ui(10.8, .medium)).foregroundColor(style.past ? pal.pastTitle : pal.title)
             + Text(" " + time).font(.mono(10.8)).foregroundColor(style.past ? pal.pastTitle : pal.time))
                .lineLimit(1).fixedSize()
                .padding(.leading, 8).padding(.trailing, 5)
                .padding(.top, rect.height > 14 ? 3 : -1.5)
                .frame(width: rect.width, height: rect.height, alignment: .topLeading)
            UnevenRoundedRectangle(topLeadingRadius: radius, bottomLeadingRadius: radius)
                .fill(style.past ? pal.pastBar : pal.bar).frame(width: 4.5, height: rect.height)
        }
        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: radius))
    }
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
        .offset(x: rect.minX, y: rect.minY)
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
