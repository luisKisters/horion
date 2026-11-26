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

/// The time zone list: what was typed on top (typing searches, Backspace takes a letter back), then "GMT+01:00  Central European
/// Standard Time – Berlin" rows by offset, 10 tall, scrolled to the event's zone or the keyboard's row.
struct PanelZoneList: View {
    @Environment(AppModel.self) private var model
    static let rows: CGFloat = 10

    var body: some View {
        let q = model.panelMenus.zoneQuery
        let list = model.zoneChoices
        let current = model.selectedEvent?.timeZoneID
        let hl = model.panelMenus.highlight
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ChromeIcon(name: .search, size: 14)
                Text(q.isEmpty ? "Type to search time zones" : q).foregroundStyle(q.isEmpty ? Theme.fg3 : Theme.fg).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).frame(height: Dim.row)
            PopSep().padding(.top, -4)
            if list.isEmpty {
                PopSection(text: "No time zone matches \u{201C}\(q)\u{201D}").padding(.bottom, 4)
            }
            ScrollViewReader { p in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(list, id: \.id) { z in
                            PopItem(check: z.id == current, key: "tz:\(z.id)", highlighted: hl == "tz:\(z.id)", action: {
                                model.closePanelMenu(); model.setSelectedTimeZone(z.id)
                            }) {
                                // the panel-wide list (v21): the city first, the zone's name after it in fg3, cut at the end
                                HStack(spacing: 8) {
                                    Text(z.offset).font(.textTab).foregroundStyle(Theme.fg3).lineLimit(1).frame(width: 72, alignment: .leading)
                                    (Text(z.city) + Text("  " + z.name).foregroundColor(Theme.fg3)).lineLimit(1).truncationMode(.tail)
                                }
                                .help("\(z.offset) \(z.name) \u{2013} \(z.city)")
                            }
                            .id(z.id)
                        }
                    }
                }
                .frame(height: min(CGFloat(list.count), Self.rows) * Dim.row)
                .onAppear { if let h = hl { p.scrollTo(String(h.dropFirst(3)), anchor: .center) } }
                .onChange(of: hl) { _, v in if let v { p.scrollTo(String(v.dropFirst(3)), anchor: .center) } }
            }
        }
    }
}

/// The Repeat menu: the common rules with a check on the event's, then "Custom": every N, the unit and the end, each changed with
/// ‹ › (Left and Right on the keyboard's row).
struct PanelRepeatMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let e = model.selectedEvent {
            let current = e.recurrence == nil && e.seriesID != nil ? nil : RepeatRules.choice(of: e.recurrence, start: e.start, math: model.math)
            let hl = model.panelMenus.highlight
            let custom = model.customRepeatTexts(e)
            ForEach(RepeatChoice.allCases, id: \.self) { c in
                let key = "rep:\(c.rawValue)"
                PopItem(check: current == c, key: key, highlighted: hl == key, action: {
                    model.closePanelMenu()
                    model.setSelectedRecurrence(RepeatRules.rule(c, start: e.start, math: model.math, until: c == .none ? nil : e.recurrence?.until))
                }) { Text(RepeatRules.label(c, start: e.start, fmt: model.fmt)) }
            }
            PopSep()
            PopSection(text: current == nil && e.recurrence != nil ? "Custom (this event)" : "Custom", indent: true)
            CustomRepeatRow(key: "rep:every", text: custom.every, checked: current == nil && e.recurrence != nil, highlighted: hl == "rep:every")
            CustomRepeatRow(key: "rep:unit", text: custom.unit, checked: false, highlighted: hl == "rep:unit")
            CustomRepeatRow(key: "rep:until", text: custom.until, checked: false, highlighted: hl == "rep:until")
        }
    }
}

/// One custom row: the value, then ‹ › that step it (the row is no button: a click on its text does nothing).
struct CustomRepeatRow: View {
    @Environment(AppModel.self) private var model
    let key: String
    let text: String
    let checked: Bool
    let highlighted: Bool
    @State private var hover = false
    @Environment(\.hoverWash) private var wash

    var body: some View {
        HStack(spacing: 10) {
            PanelIcon(name: .check, size: 14, color: Theme.fg).opacity(checked ? 1 : 0).frame(width: 14)
            Text(text).font(.textTab).foregroundStyle(Theme.fg).lineLimit(1)
            Spacer(minLength: 0)
            ChromeIconButton(icon: .left, small: true, help: "Less  \u{2190}") { model.stepCustomRepeat(key, by: -1) }
            ChromeIconButton(icon: .right, small: true, help: "More  \u{2192}") { model.stepCustomRepeat(key, by: 1) }
        }
        .padding(.leading, 10).padding(.trailing, 3)
        .frame(maxWidth: .infinity, minHeight: Dim.row, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.inner).fill(hover || highlighted ? wash : Color.clear))
        .onHover { hover = $0 }
        .tourAnchor(key)
    }
}
