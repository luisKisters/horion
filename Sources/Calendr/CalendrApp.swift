import SwiftUI
import AppKit
import CalendrKit

/// Process-wide singletons for the real app (the model is shared by the main window and the menu bar popover).
@MainActor
enum AppContext {
    static let model: AppModel = {
        let store: CalendarStore = launchOptions.demo ? DemoStore() : EventKitStore()
        return AppModel(store: store, options: launchOptions)
    }()
}

struct CalendrApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let model = AppContext.model

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environment(model)
                .frame(minWidth: 1100, minHeight: 700)
                .background(WindowConfigurator(model: model))
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 900)
        .commands { AppCommands(model: model) }

        MenuBarExtra {
            MenuBarPopover()
                .environment(model)
        } label: {
            MenuBarLabel().environment(model)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            KeyRouter.shared.install(model: AppContext.model)
            if launchOptions.demo { NSApp.activate(ignoringOtherApps: true) }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

struct AppCommands: Commands {
    let model: AppModel
    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings\u{2026}") { model.handle(.settings) }.keyboardShortcut(",")
        }
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") { model.undo() }.keyboardShortcut("z")
        }
        CommandGroup(replacing: .newItem) {
            Button("New Event") { model.handle(.createEvent) }
            Button("Refresh") { model.handle(.refresh) }.keyboardShortcut("r")
        }
    }
}

/// Hidden title bar, traffic lights inline with the sidebar, dark appearance.
struct WindowConfigurator: NSViewRepresentable {
    let model: AppModel
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { if let w = v.window { WindowChrome.apply(to: w) } }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        if let w = nsView.window { WindowChrome.apply(to: w) }
    }
}

enum WindowChrome {
    @MainActor static func apply(to w: NSWindow) {
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.styleMask.insert(.fullSizeContentView)
        w.isMovableByWindowBackground = false
        w.minSize = NSSize(width: 1100, height: 700)
        w.animationBehavior = .none
        w.backgroundColor = NSColor(Theme.bg)
    }
}
