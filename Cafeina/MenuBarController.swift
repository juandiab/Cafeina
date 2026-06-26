import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let powerAssertionManager: PowerAssertionManager
    private let loginItemManager: LoginItemManager

    init(powerAssertionManager: PowerAssertionManager, loginItemManager: LoginItemManager) {
        self.powerAssertionManager = powerAssertionManager
        self.loginItemManager = loginItemManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
        updateStatusItem()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func updateStatusItem() {
        let isEnabled = powerAssertionManager.isEnabled

        guard let button = statusItem.button else {
            return
        }

        button.image = makeStatusImage(isEnabled: isEnabled)
        button.imagePosition = .imageOnly
        button.contentTintColor = nil
        button.toolTip = isEnabled
            ? "Cafeina is keeping your Mac awake"
            : "Cafeina is off"
    }

    private func makeStatusImage(isEnabled: Bool) -> NSImage? {
        let color = isEnabled
            ? NSColor(calibratedRed: 0.55, green: 0.31, blue: 0.12, alpha: 1)
            : NSColor(calibratedWhite: 0.58, alpha: 1)
        let baseConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let colorConfiguration = NSImage.SymbolConfiguration(hierarchicalColor: color)
        let image = NSImage(
            systemSymbolName: "cup.and.saucer.fill",
            accessibilityDescription: "Cafeina"
        )?
        .withSymbolConfiguration(baseConfiguration.applying(colorConfiguration))

        image?.isTemplate = false
        return image
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggleCafeina()
        }
    }

    @objc private func toggleCafeina() {
        if powerAssertionManager.isEnabled {
            powerAssertionManager.disable()
        } else {
            powerAssertionManager.enable()
        }

        updateStatusItem()
    }

    @objc private func quitCafeina() {
        powerAssertionManager.disable()
        NSApp.terminate(nil)
    }

    @objc private func toggleOpenAtLogin() {
        loginItemManager.toggleOpenAtLogin()
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let isEnabled = powerAssertionManager.isEnabled

        let statusMenuItem = NSMenuItem(
            title: isEnabled ? "Cafeina: On" : "Cafeina: Off",
            action: nil,
            keyEquivalent: ""
        )
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem(
            title: isEnabled ? "Turn Off" : "Turn On",
            action: #selector(toggleCafeina),
            keyEquivalent: ""
        ))

        menu.addItem(.separator())
        let openAtLoginMenuItem = NSMenuItem(
            title: "Open at Login",
            action: #selector(toggleOpenAtLogin),
            keyEquivalent: ""
        )
        openAtLoginMenuItem.state = loginItemManager.menuItemState
        menu.addItem(openAtLoginMenuItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Cafeina",
            action: #selector(quitCafeina),
            keyEquivalent: "q"
        ))

        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
}
