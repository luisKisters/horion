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
