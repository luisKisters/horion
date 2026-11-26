import AppKit
import Carbon.HIToolbox

/// The two system-wide shortcuts from Settings → Shortcuts: the menu key (⌃⌘E) opens or closes the menu bar menu,
/// the app key (⌃⌘R) shows or hides the window. Carbon hot keys need no Accessibility permission.
/// Registered by the app delegate only, so headless runs never get them.
@MainActor
enum MenuBarHotKey {
    enum Action: UInt32 { case menu = 1, app = 2 }

    private static var keys: [EventHotKeyRef] = []
    private static var handler: EventHandlerRef?
    private static var settings: AppSettings?
    /// While a recorder in Settings listens or the menu is open, the shortcuts are off so the keys reach those as
    /// ordinary key presses. (macOS holds hot keys back while a menu is open and delivers them after it closed.)
    private static var paused = 0
    nonisolated static let signature = OSType(0x434C_4452)   // "CLDR"

    static func register(_ s: AppSettings) {
        guard handler == nil else { return update(s) }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, ev, _ in
            var id = EventHotKeyID()
            GetEventParameter(ev, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard id.signature == MenuBarHotKey.signature, let a = MenuBarHotKey.Action(rawValue: id.id) else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated { MenuBarHotKey.fire(a) }   // Carbon calls this on the main thread
            return noErr
        }, 1, &spec, nil, &handler)
        update(s)
    }

    /// Re-registers after a change in Settings. Does nothing before `register` (headless runs).
    static func update(_ s: AppSettings) {
        guard handler != nil else { return }
        settings = s
        apply()
    }

    static func suspend() { paused += 1; apply() }
    static func resume() { paused = max(0, paused - 1); apply() }

    private static func apply() {
        for k in keys { UnregisterEventHotKey(k) }
        keys = []
        guard paused == 0, let s = settings else { return }
        for (a, sc) in [(Action.menu, s.menuShortcut), (.app, s.appShortcut)] where sc.on {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: signature, id: a.rawValue)
            if RegisterEventHotKey(UInt32(sc.keyCode), sc.carbonModifiers, id, GetApplicationEventTarget(), 0, &ref) == noErr, let ref {
                keys.append(ref)
            }
        }
    }

    /// Runs a shortcut. While the menu is open the hot keys are off and its items take the keys instead.
    static func fire(_ a: Action) {
        switch a {
        case .menu: MenuBarControl.toggle()
        case .app: MainWindow.toggle()
        }
    }

    static func unregister() {
        for k in keys { UnregisterEventHotKey(k) }
        keys = []
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }
}
