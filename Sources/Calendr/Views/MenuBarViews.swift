import SwiftUI
import AppKit
import CalendrKit

@MainActor
enum MainWindow {
    static var openAction: (() -> Void)?

    static func show() {
        NSApp.activate(ignoringOtherApps: true)
        if let w = NSApp.windows.first(where: { !($0 is NSPanel) && $0.canBecomeMain && $0.contentView != nil && $0.isVisible == false || ($0.canBecomeMain && !($0 is NSPanel)) }) {
            w.makeKeyAndOrderFront(nil)
        } else {
            openAction?()
        }
    }
}

/// Capsule in the menu bar: "Meal Prep . in 4h 58m".
struct MenuBarLabel: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).frame(width: 4, height: 13)
            Text(Upcoming.menuBarLabel(model.upcoming)).font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 6)
    }
}

struct MenuBarPopover: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let s = model.upcoming
        // A MenuBarExtra window sizes itself from ideal sizes, and a ScrollView has none: give it its content height, capped to the screen.
        let rows = (s.next != nil ? 2 : 1) + 1 + s.sections.reduce(0) { $0 + 1 + $1.events.count }
        let maxScroll = (NSScreen.main?.visibleFrame.height ?? 900) - 130
        let scrollHeight = min(CGFloat(rows) * 24 + 6, maxScroll)
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if let n = s.next {
                        PopHeader(text: "Upcoming in \(s.untilNext)")
                        PopEventRow(e: n)
                    } else {
                        PopHeader(text: "No upcoming events")
                    }
                    PopRow(icon: "waveform.and.mic", text: "Start transcription") { model.showToast("Transcription is not available in Calendr") }
                    ForEach(s.sections) { sec in
                        PopHeader(text: sec.title)
                        ForEach(sec.events) { PopEventRow(e: $0) }
                    }
                }
                .padding(.top, 6)
            }
            .frame(height: scrollHeight)
            Rectangle().fill(Color.dyn("#2f2f2f", "#e3e3e1")).frame(height: 1).padding(.horizontal, 16).padding(.vertical, 6)
            PopFooter(title: "Open Calendr", shortcut: "\u{2318} 1") { show() }
            PopFooter(title: "Settings\u{2026}", shortcut: "\u{2318} ,") { show(); model.handle(.settings) }
            SFIcon(name: "chevron.down", size: 11).frame(height: 20)
        }
        .padding(.bottom, 2)
        .frame(width: 455)
        .background(Theme.pop)
        .onAppear { MainWindow.openAction = { openWindow(id: "main") } }
    }

    private func show() {
        MainWindow.openAction = { openWindow(id: "main") }
        MainWindow.show()
    }
}

struct PopHeader: View {
    let text: String
    var body: some View {
        Text(text).font(.ui(13)).foregroundStyle(Color(hex: "#5d5e63")).padding(.horizontal, 24).frame(height: 24, alignment: .leading)
    }
}

struct PopEventRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    let e: CalendarEvent
    @State private var hover = false
    var body: some View {
        Button {
            MainWindow.openAction = { openWindow(id: "main") }
            model.open(event: e)
            MainWindow.show()
        } label: {
            HStack(spacing: 0) {
                Group {
                    if e.status == .tentative { Stripes(color: Color(hex: "#dedede")).frame(width: 3.5, height: 13) }
                    else { Color(hex: "#dedede").frame(width: 3.5, height: 13) }
                }.clipShape(RoundedRectangle(cornerRadius: 2)).padding(.trailing, 9)
                Text("\(model.fmt.time(e.start)) \u{00B7} \(e.title)").font(.ui(13)).foregroundStyle(Color.dyn("#dcdcdc", "#2a2a2a")).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24).frame(height: 24)
            .background(hover ? Color.dyn("#2a2a2a", "#ececea") : Color.clear)
            .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { hover = $0 }
    }
}

struct PopRow: View {
    let icon: String
    let text: String
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                SFIcon(name: icon, size: 13, color: Color.dyn("#d4d4d4", "#2a2a2a")).frame(width: 16)
                Text(text).font(.ui(13)).foregroundStyle(Color.dyn("#dcdcdc", "#2a2a2a"))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24).frame(height: 24)
            .background(hover ? Color.dyn("#2a2a2a", "#ececea") : Color.clear)
            .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { hover = $0 }
    }
}

struct PopFooter: View {
    let title: String
    let shortcut: String
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.ui(13)).foregroundStyle(Color.dyn("#dbdbdb", "#2a2a2a"))
                Spacer()
                Text(shortcut).font(.ui(13)).foregroundStyle(Color(hex: "#6a6a6a"))
            }
            .padding(.horizontal, 24).frame(height: 24)
            .background(hover ? Color.dyn("#2a2a2a", "#ececea") : Color.clear)
            .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { hover = $0 }
    }
}

/// SwiftUI has no API to open a MenuBarExtra window, so control-cmd-K clicks its status item button.
@MainActor
enum MenuBarControl {
    static func open() -> Bool {
        for w in NSApp.windows where String(describing: type(of: w)).contains("StatusBar") {
            if let b = findButton(in: w.contentView) { b.performClick(nil); return true }
        }
        return false
    }
    private static func findButton(in v: NSView?) -> NSButton? {
        guard let v else { return nil }
        if let b = v as? NSButton { return b }
        for s in v.subviews { if let b = findButton(in: s) { return b } }
        return nil
    }
}
