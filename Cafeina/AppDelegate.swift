import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let powerAssertionManager = PowerAssertionManager()
    private let loginItemManager = LoginItemManager()
    private let powerSourceMonitor = PowerSourceMonitor()
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController(
            powerAssertionManager: powerAssertionManager,
            loginItemManager: loginItemManager,
            powerSourceMonitor: powerSourceMonitor
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        powerAssertionManager.disable()
    }
}
