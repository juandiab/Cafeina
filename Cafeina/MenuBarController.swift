import AppKit
import UniformTypeIdentifiers

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let powerAssertionManager: PowerAssertionManager
    private let loginItemManager: LoginItemManager
    private let powerSourceMonitor: PowerSourceMonitor
    private let appTriggerMonitor: AppTriggerMonitor
    private let displayMonitor: DisplayMonitor
    private let hotKeyManager = HotKeyManager()
    private let notificationManager = NotificationManager()

    /// Refreshes the menu-bar countdown while a timed session is active; nil otherwise.
    private var countdownTimer: Timer?

    /// Whether the battery auto-off condition held at the last evaluation.
    /// Keep-awake is only turned off when the condition newly becomes true, so an
    /// explicit user enable while already on battery is respected.
    private var isBatteryAutoOffConditionMet = false

    /// Whether an automatic keep-awake rule (trigger app running / presenting) held
    /// at the last evaluation. Rules only act on transitions, so a manual Turn Off
    /// while a trigger app keeps running is respected until the rule re-arms.
    private var isAutoKeepAwakeConditionMet = false

    /// True while the current keep-awake session was started by an automatic rule.
    /// Cleared by every manual enable/disable and by battery auto-off, so a rule
    /// ending never turns off a session the user (or the battery logic) owns.
    private var isKeepAwakeEnabledAutomatically = false

    private let keepAwakeOptions: [KeepAwakeDuration] = [
        .minutes(30),
        .minutes(60),
        .minutes(120),
        .indefinite
    ]

    init(
        powerAssertionManager: PowerAssertionManager,
        loginItemManager: LoginItemManager,
        powerSourceMonitor: PowerSourceMonitor,
        appTriggerMonitor: AppTriggerMonitor,
        displayMonitor: DisplayMonitor
    ) {
        self.powerAssertionManager = powerAssertionManager
        self.loginItemManager = loginItemManager
        self.powerSourceMonitor = powerSourceMonitor
        self.appTriggerMonitor = appTriggerMonitor
        self.displayMonitor = displayMonitor
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        self.powerAssertionManager.onStateChange = { [weak self] in
            Task { @MainActor in
                self?.reconcileAutoKeepAwakeOwnership()
                self?.updateStatusItem()
            }
        }

        self.powerSourceMonitor.onChange = { [weak self] in
            self?.evaluateBatteryAutoOff()
        }

        self.appTriggerMonitor.onChange = { [weak self] in
            self?.evaluateAutoKeepAwake()
        }

        self.displayMonitor.onChange = { [weak self] in
            self?.evaluateAutoKeepAwake()
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
        isKeepAwakeEnabledAutomatically = false
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
        isKeepAwakeEnabledAutomatically = false
        powerAssertionManager.enable(for: duration)
    }

    @objc private func turnOff() {
        isKeepAwakeEnabledAutomatically = false
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
        // Battery state gates the automatic keep-awake rules, so re-evaluate them too.
        defer { evaluateAutoKeepAwake() }

        guard isConditionMet, !wasConditionMet, powerAssertionManager.isEnabled else {
            return
        }
        isKeepAwakeEnabledAutomatically = false
        powerAssertionManager.disable()
        notificationManager.notifyTurnedOff(reason: batteryAutoOffReason())
    }

    // MARK: - Automatic keep-awake rules (trigger apps / presenting)

    /// Turns keep-awake on when an automatic rule newly starts holding (a trigger
    /// app launches, or an external/mirrored/AirPlay display appears while "Keep
    /// Awake While Presenting" is on) and off again when no rule holds anymore —
    /// but only if the rules turned it on. Precedence:
    /// - Manual actions win: they clear `isKeepAwakeEnabledAutomatically`, so a
    ///   manual Turn Off is not undone until the rules re-arm (all trigger apps quit
    ///   / presenting ends, then one starts again), and a manual enable persists
    ///   after the trigger ends.
    /// - Battery auto-off wins over the rules: they never turn keep-awake on while a
    ///   battery auto-off condition holds, and battery auto-off clears the flag.
    private func evaluateAutoKeepAwake() {
        let wasConditionMet = isAutoKeepAwakeConditionMet
        let isConditionMet = autoKeepAwakeConditionHolds() && !isBatteryAutoOffConditionMet
        isAutoKeepAwakeConditionMet = isConditionMet

        guard isConditionMet != wasConditionMet else {
            return
        }

        if isConditionMet {
            guard !powerAssertionManager.isEnabled else {
                return
            }
            powerAssertionManager.enable(for: .indefinite)
            isKeepAwakeEnabledAutomatically = powerAssertionManager.isEnabled
        } else if isKeepAwakeEnabledAutomatically {
            isKeepAwakeEnabledAutomatically = false
            powerAssertionManager.disable()
        }
    }

    /// Rules only ever start an `.indefinite` session. If the session is gone or has a
    /// different duration, something else (menu, hotkey, "Until a Time…", a Shortcut,
    /// timer expiry, battery auto-off) changed it, so the rules no longer own it.
    /// Called after every `PowerAssertionManager` state change.
    private func reconcileAutoKeepAwakeOwnership() {
        guard isKeepAwakeEnabledAutomatically else {
            return
        }
        if !powerAssertionManager.isEnabled || powerAssertionManager.activeDuration != .indefinite {
            isKeepAwakeEnabledAutomatically = false
        }
    }

    private func autoKeepAwakeConditionHolds() -> Bool {
        if appTriggerMonitor.isAnyTriggerAppRunning {
            return true
        }
        return AppSettings.keepAwakeWhilePresenting && displayMonitor.isPresenting
    }

    /// Short explanation of why the rules are keeping the Mac awake, e.g.
    /// "Zoom is running", "presenting". Nil unless the current session is automatic.
    private func autoKeepAwakeReason() -> String? {
        guard isKeepAwakeEnabledAutomatically else {
            return nil
        }

        var reasons: [String] = []
        let names = appTriggerMonitor.runningTriggerAppNames
        if names.count == 1 {
            reasons.append("\(names[0]) is running")
        } else if names.count > 1 {
            reasons.append("\(names.joined(separator: ", ")) are running")
        }
        if AppSettings.keepAwakeWhilePresenting, displayMonitor.isPresenting {
            reasons.append("presenting")
        }
        return reasons.isEmpty ? nil : reasons.joined(separator: ", ")
    }

    @objc private func toggleKeepAwakeWhilePresenting() {
        AppSettings.keepAwakeWhilePresenting.toggle()
        evaluateAutoKeepAwake()
    }

    @objc private func addTriggerApp(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else {
            return
        }
        appTriggerMonitor.add(bundleID: bundleID, name: sender.title)
    }

    @objc private func removeTriggerApp(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else {
            return
        }
        appTriggerMonitor.remove(bundleID: bundleID)
    }

    @objc private func chooseTriggerApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose Apps That Keep the Mac Awake"
        panel.prompt = "Add"
        panel.message = "Cafeina keeps the Mac awake while the chosen apps are running."
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.treatsFilePackagesAsDirectories = false

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else {
            return
        }

        for url in panel.urls {
            guard let bundleID = Bundle(url: url)?.bundleIdentifier, !bundleID.isEmpty else {
                continue
            }
            var name = FileManager.default.displayName(atPath: url.path)
            if name.hasSuffix(".app") {
                name = String(name.dropLast(4))
            }
            if name.isEmpty {
                name = url.deletingPathExtension().lastPathComponent
            }
            appTriggerMonitor.add(bundleID: bundleID, name: name)
        }
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
        addTriggerSection(to: menu)

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

    /// Adds the automatic-rule items: the "Keep Awake While Running" submenu and the
    /// "Keep Awake While Presenting" checkbox.
    private func addTriggerSection(to menu: NSMenu) {
        let triggerAppsItem = NSMenuItem(title: "Keep Awake While Running", action: nil, keyEquivalent: "")
        triggerAppsItem.submenu = makeTriggerAppsMenu()
        triggerAppsItem.toolTip = "Keeps the Mac awake while any of the chosen apps is running."
        menu.addItem(triggerAppsItem)

        let presentingItem = NSMenuItem(
            title: "Keep Awake While Presenting",
            action: #selector(toggleKeepAwakeWhilePresenting),
            keyEquivalent: ""
        )
        presentingItem.state = AppSettings.keepAwakeWhilePresenting ? .on : .off
        presentingItem.toolTip = "Turns on when an external, mirrored, or AirPlay display connects."
        menu.addItem(presentingItem)
    }

    private func makeTriggerAppsMenu() -> NSMenu {
        let submenu = NSMenu()
        let maxRunningAppsShown = 15
        let ownBundleID = Bundle.main.bundleIdentifier

        // Configured trigger apps (checked; click removes).
        let configured = appTriggerMonitor.triggerBundleIDs
            .map { (bundleID: $0, name: appTriggerMonitor.name(forBundleID: $0)) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if configured.isEmpty {
            // No action, so it renders disabled as a hint.
            submenu.addItem(NSMenuItem(title: "No Apps Selected", action: nil, keyEquivalent: ""))
        }
        for app in configured {
            let item = NSMenuItem(title: app.name, action: #selector(removeTriggerApp(_:)), keyEquivalent: "")
            item.representedObject = app.bundleID
            item.state = .on
            item.image = menuIcon(forBundleID: app.bundleID)
            item.toolTip = "Click to stop keeping the Mac awake while \(app.name) runs."
            submenu.addItem(item)
        }

        // Currently running regular apps that are not yet triggers (click adds).
        let running = NSWorkspace.shared.runningApplications
            .filter { app in
                guard app.activationPolicy == .regular, !app.isTerminated,
                      let bundleID = app.bundleIdentifier, bundleID != ownBundleID else {
                    return false
                }
                return !appTriggerMonitor.contains(bundleID: bundleID)
            }
            .sorted { ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "") == .orderedAscending }
            .prefix(maxRunningAppsShown)
        if !running.isEmpty {
            submenu.addItem(.separator())
            for app in running {
                guard let bundleID = app.bundleIdentifier else {
                    continue
                }
                let name = app.localizedName ?? bundleID
                let item = NSMenuItem(title: name, action: #selector(addTriggerApp(_:)), keyEquivalent: "")
                item.representedObject = bundleID
                item.image = app.icon.map(scaledMenuIcon)
                item.toolTip = "Keep the Mac awake while \(name) is running."
                submenu.addItem(item)
            }
        }

        submenu.addItem(.separator())
        submenu.addItem(NSMenuItem(title: "Choose App…", action: #selector(chooseTriggerApp), keyEquivalent: ""))
        return submenu
    }

    private func menuIcon(forBundleID bundleID: String) -> NSImage? {
        if let icon = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == bundleID })?.icon {
            return scaledMenuIcon(icon)
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return scaledMenuIcon(NSWorkspace.shared.icon(forFile: url.path))
    }

    private func scaledMenuIcon(_ image: NSImage) -> NSImage {
        guard let copy = image.copy() as? NSImage else {
            return image
        }
        copy.size = NSSize(width: 16, height: 16)
        return copy
    }

    private func statusTitle(isEnabled: Bool) -> String {
        var title = keepAwakeStatusTitle(isEnabled: isEnabled)
        if isEnabled, let reason = autoKeepAwakeReason() {
            title += " (\(reason))"
        }

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
