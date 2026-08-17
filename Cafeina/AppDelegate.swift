import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let powerAssertionManager = PowerAssertionManager()
    let loginItemManager = LoginItemManager()
    let powerSourceMonitor = PowerSourceMonitor()
    let appTriggerMonitor = AppTriggerMonitor()
    let displayMonitor = DisplayMonitor()
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController(
            powerAssertionManager: powerAssertionManager,
            loginItemManager: loginItemManager,
            powerSourceMonitor: powerSourceMonitor,
            appTriggerMonitor: appTriggerMonitor,
            displayMonitor: displayMonitor
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        powerAssertionManager.disable()
    }

    /// Reopening a menu-bar-only app (Dock, Finder, Spotlight) shows nothing by default.
    /// Surface the About window so a relaunch visibly does something.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            AboutWindowController.shared.show()
        }
        return false
    }
}
