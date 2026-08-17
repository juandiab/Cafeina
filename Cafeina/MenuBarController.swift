import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let powerAssertionManager: PowerAssertionManager
    private let loginItemManager: LoginItemManager
    private let powerSourceMonitor: PowerSourceMonitor
    private let hotKeyManager = HotKeyManager()
    private let notificationManager = NotificationManager()

    /// Refreshes the menu-bar countdown while a timed session is active; nil otherwise.
    private var countdownTimer: Timer?

    /// Whether the battery auto-off condition held at the last evaluation.
    /// Keep-awake is only turned off when the condition newly becomes true, so an
    /// explicit user enable while already on battery is respected.
    private var isBatteryAutoOffConditionMet = false

    private let keepAwakeOptions: [KeepAwakeDuration] = [
        .minutes(30),
        .minutes(60),
        .minutes(120),
        .indefinite
    ]

    init(
        powerAssertionManager: PowerAssertionManager,
        loginItemManager: LoginItemManager,
        powerSourceMonitor: PowerSourceMonitor
    ) {
        self.powerAssertionManager = powerAssertionManager
        self.loginItemManager = loginItemManager
        self.powerSourceMonitor = powerSourceMonitor
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        self.powerAssertionManager.onStateChange = { [weak self] in
            Task { @MainActor in
                self?.updateStatusItem()
            }
        }

        self.powerSourceMonitor.onChange = { [weak self] in
            self?.evaluateBatteryAutoOff()
        }

        configureStatusItem()
        configureHotKeyAndNotifications()
        updateStatusItem()
        evaluateBatteryAutoOff()
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
        updateCountdown()
    }

    private func tooltipText(isEnabled: Bool) -> String {
        "\(statusTooltipText(isEnabled: isEnabled))\nClick to toggle. Right-click or Control-click opens the menu."
    }

    private func statusTooltipText(isEnabled: Bool) -> String {
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
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let image = NSImage(
            systemSymbolName: isEnabled ? "cup.and.saucer.fill" : "cup.and.saucer",
            accessibilityDescription: "Cafeina"
        )?
        .withSymbolConfiguration(configuration)

        image?.isTemplate = true
        return image
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isControlClick = event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true
        if event?.type == .rightMouseUp || isControlClick {
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

    @objc private func toggleAllowDisplaySleep() {
        powerAssertionManager.allowDisplaySleep.toggle()
    }

    @objc private func toggleDisableWhenOnBattery() {
        AppSettings.disableWhenOnBattery.toggle()
        evaluateBatteryAutoOff()
    }

    @objc private func toggleDisableBelowBatteryPercent() {
        AppSettings.disableBelowBatteryPercent.toggle()
        evaluateBatteryAutoOff()
    }

    /// Turns keep-awake off when a battery auto-off condition newly becomes true.
    /// Called on power source changes and when a battery setting is toggled.
    /// Keep-awake is never re-enabled automatically.
    private func evaluateBatteryAutoOff() {
        let wasConditionMet = isBatteryAutoOffConditionMet
        let isConditionMet = batteryAutoOffConditionHolds()
        isBatteryAutoOffConditionMet = isConditionMet

        guard isConditionMet, !wasConditionMet, powerAssertionManager.isEnabled else {
            return
        }
        powerAssertionManager.disable()
        notificationManager.notifyTurnedOff(reason: batteryAutoOffReason())
    }

    private func batteryAutoOffConditionHolds() -> Bool {
        guard powerSourceMonitor.isOnBattery else {
            return false
        }

        if AppSettings.disableWhenOnBattery {
            return true
        }

        if AppSettings.disableBelowBatteryPercent,
           let percent = powerSourceMonitor.batteryPercent,
           percent <= AppSettings.lowBatteryThresholdPercent {
            return true
        }

        return false
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
        // Enabled state is managed explicitly below rather than by target/action lookup.
        menu.autoenablesItems = false
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
        addUntilTimeItem(to: keepAwakeMenu)

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

        menu.addItem(makeAllowDisplaySleepMenuItem())
        addPreferenceItems(to: menu)
        menu.addItem(makeBatteryMenuItem())

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

    private func makeAllowDisplaySleepMenuItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: "Allow Display to Sleep",
            action: #selector(toggleAllowDisplaySleep),
            keyEquivalent: ""
        )
        item.state = powerAssertionManager.allowDisplaySleep ? .on : .off
        item.toolTip = "Keeps the Mac awake but lets the screen turn off."
        return item
    }

    private func makeBatteryMenuItem() -> NSMenuItem {
        let hasBattery = powerSourceMonitor.batteryPercent != nil

        let onBatteryItem = NSMenuItem(
            title: "Turn Off When on Battery",
            action: #selector(toggleDisableWhenOnBattery),
            keyEquivalent: ""
        )
        onBatteryItem.state = AppSettings.disableWhenOnBattery ? .on : .off
        onBatteryItem.isEnabled = hasBattery

        let lowBatteryItem = NSMenuItem(
            title: "Turn Off Below \(AppSettings.lowBatteryThresholdPercent)%",
            action: #selector(toggleDisableBelowBatteryPercent),
            keyEquivalent: ""
        )
        lowBatteryItem.state = AppSettings.disableBelowBatteryPercent ? .on : .off
        lowBatteryItem.isEnabled = hasBattery

        let batteryMenu = NSMenu()
        batteryMenu.autoenablesItems = false
        batteryMenu.addItem(onBatteryItem)
        batteryMenu.addItem(lowBatteryItem)

        let batteryItem = NSMenuItem(title: "Battery", action: nil, keyEquivalent: "")
        batteryItem.submenu = batteryMenu
        return batteryItem
    }

    private func statusTitle(isEnabled: Bool) -> String {
        let title = keepAwakeStatusTitle(isEnabled: isEnabled)

        guard powerSourceMonitor.isOnBattery, let percent = powerSourceMonitor.batteryPercent else {
            return title
        }
        return "\(title) · Battery \(percent)%"
    }

    private func keepAwakeStatusTitle(isEnabled: Bool) -> String {
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
            alert.informativeText = "Look for the cup icon near the clock. Left-click toggles keep-awake. Right-click or Control-click opens the menu with timers, About, Privacy, and Support."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Got It")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    // MARK: - Until a Time…

    /// Appends the "Until a Time…" entry to the Keep Awake submenu.
    private func addUntilTimeItem(to keepAwakeMenu: NSMenu) {
        keepAwakeMenu.addItem(.separator())

        let item = NSMenuItem(
            title: "Until a Time…",
            action: #selector(showUntilTimePanel),
            keyEquivalent: ""
        )
        if case .until = powerAssertionManager.activeDuration, powerAssertionManager.isEnabled {
            item.state = .on
        } else {
            item.state = .off
        }
        keepAwakeMenu.addItem(item)
    }

    @objc private func showUntilTimePanel() {
        UntilTimePanelController.shared.show { [weak self] date in
            self?.powerAssertionManager.enable(for: .until(date))
        }
    }

    // MARK: - Preferences (countdown, global shortcut, notifications)

    /// Appends the checkbox items that follow "Allow Display to Sleep".
    private func addPreferenceItems(to menu: NSMenu) {
        let countdownItem = NSMenuItem(
            title: "Show Time Remaining in Menu Bar",
            action: #selector(toggleShowTimeRemaining),
            keyEquivalent: ""
        )
        countdownItem.state = AppSettings.showTimeRemainingInMenuBar ? .on : .off
        countdownItem.toolTip = "Shows a countdown next to the cup icon during timed sessions."
        menu.addItem(countdownItem)

        let shortcutItem = NSMenuItem(
            title: "Global Shortcut \(HotKeyManager.shortcutDescription)",
            action: #selector(toggleGlobalShortcut),
            keyEquivalent: ""
        )
        if AppSettings.globalShortcutEnabled {
            // `.mixed` flags an enabled setting whose registration failed (e.g. another app owns the keys).
            shortcutItem.state = hotKeyManager.isRegistered ? .on : .mixed
            shortcutItem.toolTip = hotKeyManager.isRegistered
                ? "Toggles keep-awake from any app."
                : "Could not register the shortcut; another app may already be using it."
        } else {
            shortcutItem.state = .off
            shortcutItem.toolTip = "Toggles keep-awake from any app."
        }
        menu.addItem(shortcutItem)

        let notificationsItem = NSMenuItem(
            title: "Notify When Turned Off Automatically",
            action: #selector(toggleNotifications),
            keyEquivalent: ""
        )
        notificationsItem.state = AppSettings.notificationsEnabled ? .on : .off
        notificationsItem.toolTip = "Posts a quiet notification when a timer ends or battery auto-off turns Cafeina off."
        menu.addItem(notificationsItem)
    }

    @objc private func toggleShowTimeRemaining() {
        AppSettings.showTimeRemainingInMenuBar.toggle()
        updateCountdown()
    }

    @objc private func toggleGlobalShortcut() {
        AppSettings.globalShortcutEnabled.toggle()
        applyGlobalShortcutSetting()
    }

    @objc private func toggleNotifications() {
        AppSettings.notificationsEnabled.toggle()
    }

    private func configureHotKeyAndNotifications() {
        hotKeyManager.onHotKey = { [weak self] in
            self?.toggleCafeina()
        }
        applyGlobalShortcutSetting()

        powerAssertionManager.onExpired = { [weak self] in
            self?.notificationManager.notifyTurnedOff(reason: .timerExpired)
        }
    }

    private func applyGlobalShortcutSetting() {
        if AppSettings.globalShortcutEnabled {
            hotKeyManager.register()
        } else {
            hotKeyManager.unregister()
        }
    }

    /// Mirrors the precedence in `batteryAutoOffConditionHolds()` to describe why auto-off fired.
    private func batteryAutoOffReason() -> NotificationManager.Reason {
        AppSettings.disableWhenOnBattery
            ? .onBattery
            : .lowBattery(thresholdPercent: AppSettings.lowBatteryThresholdPercent)
    }

    // MARK: - Menu-bar countdown

    /// Shows the remaining time next to the icon during timed sessions (when enabled)
    /// and keeps the refresh timer running only while there is something to count down.
    private func updateCountdown() {
        guard let button = statusItem.button else {
            return
        }

        if AppSettings.showTimeRemainingInMenuBar, let expiresAt = powerAssertionManager.expiresAt {
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.title = Self.countdownText(secondsRemaining: expiresAt.timeIntervalSinceNow)
            button.imagePosition = .imageLeading
            startCountdownTimerIfNeeded()
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
            stopCountdownTimer()
        }
    }

    /// Countdown label for the menu bar: "42m", "1h 05m", "<1m". Minutes are rounded up.
    nonisolated static func countdownText(secondsRemaining: TimeInterval) -> String {
        guard secondsRemaining >= 60 else {
            return "<1m"
        }
        let totalMinutes = Int((secondsRemaining / 60).rounded(.up))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? String(format: "%dh %02dm", hours, minutes) : "\(minutes)m"
    }

    private func startCountdownTimerIfNeeded() {
        guard countdownTimer == nil else {
            return
        }
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            // Scheduled on the main run loop, so it always fires on the main thread.
            MainActor.assumeIsolated {
                self?.updateCountdown()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
}
