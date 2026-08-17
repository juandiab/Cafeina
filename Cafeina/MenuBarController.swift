import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let powerAssertionManager: PowerAssertionManager
    private let loginItemManager: LoginItemManager

    private let keepAwakeOptions: [KeepAwakeDuration] = [
        .minutes(30),
        .minutes(60),
        .minutes(120),
        .indefinite
    ]

    init(powerAssertionManager: PowerAssertionManager, loginItemManager: LoginItemManager) {
        self.powerAssertionManager = powerAssertionManager
        self.loginItemManager = loginItemManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        self.powerAssertionManager.onStateChange = { [weak self] in
            Task { @MainActor in
                self?.updateStatusItem()
            }
        }

        configureStatusItem()
        updateStatusItem()
        showFirstLaunchHintIfNeeded()
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
        button.toolTip = tooltipText(isEnabled: isEnabled)
    }

    private func tooltipText(isEnabled: Bool) -> String {
        guard isEnabled else {
            return "Cafeina is off"
        }

        if let expiresAt = powerAssertionManager.expiresAt {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Cafeina is keeping your Mac awake until \(formatter.string(from: expiresAt))"
        }

        if let duration = powerAssertionManager.activeDuration {
            return "Cafeina is keeping your Mac awake \(duration.statusSuffix)"
        }

        return "Cafeina is keeping your Mac awake"
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
            powerAssertionManager.enable(for: .indefinite)
        }
    }

    @objc private func enableForDuration(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? KeepAwakeDuration else {
            return
        }
        powerAssertionManager.enable(for: duration)
    }

    @objc private func turnOff() {
        powerAssertionManager.disable()
    }

    @objc private func quitCafeina() {
        powerAssertionManager.disable()
        NSApp.terminate(nil)
    }

    @objc private func toggleOpenAtLogin() {
        loginItemManager.toggleOpenAtLogin()
    }

    @objc private func showAbout() {
        AboutWindowController.shared.show()
    }

    @objc private func openPrivacyPolicy() {
        NSWorkspace.shared.open(AppLinks.privacyPolicy)
    }

    @objc private func openSupport() {
        NSWorkspace.shared.open(AppLinks.supportEmail)
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let isEnabled = powerAssertionManager.isEnabled

        let statusMenuItem = NSMenuItem(
            title: statusTitle(isEnabled: isEnabled),
            action: nil,
            keyEquivalent: ""
        )
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(.separator())

        let keepAwakeMenu = NSMenu()
        for option in keepAwakeOptions {
            let item = NSMenuItem(
                title: option.menuTitle,
                action: #selector(enableForDuration(_:)),
                keyEquivalent: ""
            )
            item.representedObject = option
            item.state = (isEnabled && powerAssertionManager.activeDuration == option) ? .on : .off
            keepAwakeMenu.addItem(item)
        }

        let keepAwakeItem = NSMenuItem(title: "Keep Awake", action: nil, keyEquivalent: "")
        keepAwakeItem.submenu = keepAwakeMenu
        menu.addItem(keepAwakeItem)

        let turnOffItem = NSMenuItem(
            title: "Turn Off",
            action: #selector(turnOff),
            keyEquivalent: ""
        )
        turnOffItem.isEnabled = isEnabled
        menu.addItem(turnOffItem)

        menu.addItem(.separator())

        let openAtLoginMenuItem = NSMenuItem(
            title: "Open at Login",
            action: #selector(toggleOpenAtLogin),
            keyEquivalent: ""
        )
        openAtLoginMenuItem.state = loginItemManager.menuItemState
        menu.addItem(openAtLoginMenuItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "About Cafeina…", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Privacy Policy", action: #selector(openPrivacyPolicy), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Support…", action: #selector(openSupport), keyEquivalent: ""))

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Cafeina",
            action: #selector(quitCafeina),
            keyEquivalent: "q"
        ))

        for item in menu.items {
            item.target = self
            if let submenu = item.submenu {
                for subitem in submenu.items {
                    subitem.target = self
                }
            }
        }

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func statusTitle(isEnabled: Bool) -> String {
        guard isEnabled else {
            return "Cafeina: Off"
        }

        if let expiresAt = powerAssertionManager.expiresAt {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Cafeina: On until \(formatter.string(from: expiresAt))"
        }

        return "Cafeina: On"
    }

    private func showFirstLaunchHintIfNeeded() {
        let key = "didShowMenuBarHint"
        guard UserDefaults.standard.bool(forKey: key) == false else {
            return
        }
        UserDefaults.standard.set(true, forKey: key)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let alert = NSAlert()
            alert.messageText = "Cafeina is in your menu bar"
            alert.informativeText = "Look for the cup icon near the clock. Left-click toggles keep-awake; right-click opens timers, About, Privacy, and Support."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Got It")
            alert.runModal()
        }
    }
}
