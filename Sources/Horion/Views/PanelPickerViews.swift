import SwiftUI
import HorionKit

// The pickers that drop down from the panel's fields (model: `Model/PanelPickers.swift`). They are `PanelMenuLayer` menus: the
// pop surface, 28 pt `PopItem` rows, the keyboard's row washed.

/// The start or end time list: 15-minute steps, 8 rows tall, scrolled to the current (or typed) time. The end list adds the length.
struct PanelTimeList: View {
    @Environment(AppModel.self) private var model
    let menu: PanelMenu
    static let rows: CGFloat = 8

    var body: some View {
        let slots = model.timeChoices(menu)
        let hl = model.highlightedMinutes
        ScrollViewReader { p in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(slots, id: \.self) { m in
                        PopItem(key: "time:\(m)", highlighted: hl == m, action: { model.pickTime(menu, m) }) {
                            HStack(spacing: 6) {
                                Text(model.fmt.time(minutes: m)).font(.textTab)
                                if menu == .endTime, let len = model.timeLength(m) {
                                    Text(len).font(.smallTab).foregroundStyle(Theme.fg3).lineLimit(1)
                                }
                            }
                        }
                        .id(m)
                    }
                }
            }
            .frame(height: min(CGFloat(slots.count), Self.rows) * Dim.row)
            .onAppear { if let hl { p.scrollTo(hl, anchor: .center) } }
            .onChange(of: hl) { _, v in if let v { p.scrollTo(v, anchor: .center) } }
        }
    }
}

/// The mini month under the date field: the month and ‹ ›, weekday letters, six weeks of days. Today on the accent pill, the event's
/// day on the selected fill, the keyboard's day in the focus ring. Days of the months around in fg3.
struct PanelDatePicker: View {
    @Environment(AppModel.self) private var model
    static let cell = CGSize(width: 32, height: 28)

    var body: some View {
        let math = model.math
        let month = model.panelMenus.pickMonth ?? math.startOfMonth(model.selectedEvent?.start ?? model.now)
        let chosen = model.selectedEvent.map { math.startOfDay($0.start) }
        let cursor = model.panelMenus.picking ? model.panelMenus.pickDay : nil
        let first = math.calendar.firstWeekday
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 2) {
                (Text(verbatim: model.fmt.monthLong(month)).font(.textMedium).foregroundColor(Theme.fg)
                 + Text(verbatim: " " + String(math.year(month))).font(.textTab).foregroundColor(Theme.fg3))
                    .frame(maxWidth: .infinity, alignment: .leading)
                ChromeIconButton(icon: .left, small: true, help: "Previous month  \u{21DE}") { model.stepPickMonth(-1) }
                ChromeIconButton(icon: .right, small: true, help: "Next month  \u{21DF}") { model.stepPickMonth(1) }
            }
            .padding(.leading, 10).padding(.trailing, 2)
            .frame(height: Dim.row)
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(String(Fmt.weekdayShort[(first - 1 + i) % 7].prefix(2))).font(.small).foregroundStyle(Theme.fg3)
                        .frame(width: Self.cell.width, height: 22)
                }
            }
            ForEach(Array(math.monthGrid(for: month).enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week, id: \.self) { d in
                        PickerDay(day: d, inMonth: math.isSameMonth(d, month), today: math.isSameDay(d, model.now),
                                  chosen: chosen.map { math.isSameDay($0, d) } ?? false, cursor: cursor.map { math.isSameDay($0, d) } ?? false)
                    }
                }
            }
        }
    }
}

struct PickerDay: View {
    @Environment(AppModel.self) private var model
    let day: Date
    let inMonth: Bool
    let today: Bool
    let chosen: Bool
    let cursor: Bool
    @State private var hover = false
    @Environment(\.hoverWash) private var wash

    var body: some View {
        Button { model.pickDate(day) } label: {
            Text(verbatim: String(model.math.day(day)))
                .font(today ? .smallTabSemibold : .smallTab)
                .foregroundStyle(today ? Theme.onAct : (inMonth ? Theme.fg : Theme.fg3))
                .frame(width: PanelDatePicker.cell.width - 4, height: PanelDatePicker.cell.height - 4)
                .background(RoundedRectangle(cornerRadius: Radius.small).fill(today ? Theme.act : (chosen ? Theme.selected : (hover ? wash : Color.clear))))
                .overlay { if cursor { RoundedRectangle(cornerRadius: Radius.small).strokeBorder(Theme.focus, lineWidth: 2) } }
                .frame(width: PanelDatePicker.cell.width, height: PanelDatePicker.cell.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .tourAnchor("day:\(model.math.day(day))-\(model.math.month(day))")
    }
}
