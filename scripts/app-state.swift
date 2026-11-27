// Looks at a running app from outside, for scripts/cua-check.sh. Needs no permission.
//   app-state state <pid>   prints: hidden=0 active=1 window=1 menu=0
//                           window: a normal window of the app is on screen; menu: one of its menus is open
//   app-state hide <pid>    hides the app (what ⌘H does)
//   app-state quit <pid>    asks the app to quit
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let pid = pid_t(args[2]), let app = NSRunningApplication(processIdentifier: pid) else {
    print("usage: app-state state|hide|quit <pid>   (or the app is not running)")
    exit(2)
}
switch args[1] {
case "hide": app.hide()
case "quit": app.terminate()
case "state":
    let onScreen = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[CFString: Any]] ?? []
    let layers = onScreen.filter { ($0[kCGWindowOwnerPID] as? Int) == Int(pid) }.compactMap { $0[kCGWindowLayer] as? Int }
    let menuLayer = Int(CGWindowLevelForKey(.popUpMenuWindow))
    func bit(_ b: Bool) -> Int { b ? 1 : 0 }
    print("hidden=\(bit(app.isHidden)) active=\(bit(app.isActive)) window=\(bit(layers.contains(0))) menu=\(bit(layers.contains(menuLayer)))")
default: exit(2)
}
