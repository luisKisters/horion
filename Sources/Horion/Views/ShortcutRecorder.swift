import AppKit
import SwiftUI

/// Records a global shortcut: click the cap, press the keys (with ⌃, ⌥ or ⌘). Esc cancels. The switch turns the shortcut off,
/// and "Reset" brings back the default. While it listens, the global shortcuts are suspended so the keys reach it.
struct ShortcutRecorder: View {
    let shortcut: GlobalShortcut
    /// The other global shortcut: the same keys cannot be used twice.
    let other: GlobalShortcut
    let fallback: GlobalShortcut
    let onChange: (GlobalShortcut) -> Void

    @State private var recording = false
    @State private var monitor: Any?
    @State private var hover = false

    var body: some View {
        HStack(spacing: 10) {
            if !shortcut.sameKeys(fallback) && !recording {
                Button("Reset") { var s = fallback; s.on = true; onChange(s) }
                    .buttonStyle(.plain).font(.small).foregroundStyle(Theme.fg3)
            }
            Button { recording ? stop() : start() } label: {
                Group {
                    if recording { Text("Type a shortcut").font(.small).foregroundStyle(Theme.fg2) }
                    else { Keycap(text: shortcut.display).opacity(shortcut.on ? 1 : 0.5) }
                }
                .frame(minWidth: 110, minHeight: 26)
                .background(RoundedRectangle(cornerRadius: Radius.control).fill(hover || recording ? Theme.bg2 : Theme.bg1))
                .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(recording ? Theme.fg3 : Theme.hair, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hover = $0 }
            .help(recording ? "Press the new shortcut. Esc cancels." : "Click to change")
            PanelSwitch(label: "", isOn: shortcut.on) { var s = shortcut; s.on.toggle(); onChange(s) }
        }
        .onDisappear { stop() }
    }

    private func start() {
        recording = true
        MenuBarHotKey.suspend()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            MainActor.assumeIsolated {
                if e.keyCode == 53 { stop(); return }
                guard let s = GlobalShortcut(e), !(other.on && s.sameKeys(other)) else { NSSound.beep(); return }
                onChange(s)
                stop()
            }
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording { recording = false; MenuBarHotKey.resume() }
    }
}
