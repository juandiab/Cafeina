import Foundation

/// User preferences persisted in `UserDefaults`.
enum AppSettings {
    private enum Key {
        static let disableWhenOnBattery = "disableWhenOnBattery"
        static let disableBelowBatteryPercent = "disableBelowBatteryPercent"
        static let allowDisplaySleep = "allowDisplaySleep"
    }

    /// Battery percentage at or below which keep-awake turns off when
    /// `disableBelowBatteryPercent` is enabled.
    static let lowBatteryThresholdPercent = 20

    static var disableWhenOnBattery: Bool {
        get { UserDefaults.standard.bool(forKey: Key.disableWhenOnBattery) }
        set { UserDefaults.standard.set(newValue, forKey: Key.disableWhenOnBattery) }
    }

    static var disableBelowBatteryPercent: Bool {
        get { UserDefaults.standard.bool(forKey: Key.disableBelowBatteryPercent) }
        set { UserDefaults.standard.set(newValue, forKey: Key.disableBelowBatteryPercent) }
    }

    static var allowDisplaySleep: Bool {
        get { UserDefaults.standard.bool(forKey: Key.allowDisplaySleep) }
        set { UserDefaults.standard.set(newValue, forKey: Key.allowDisplaySleep) }
    }

    // MARK: - Timers, global shortcut, notifications

    private enum TimerKey {
        static let showTimeRemainingInMenuBar = "showTimeRemainingInMenuBar"
        static let globalShortcutEnabled = "globalShortcutEnabled"
        static let notificationsEnabled = "notificationsEnabled"
    }

    /// Show the remaining time of a timed session next to the menu-bar icon. Defaults to on.
    static var showTimeRemainingInMenuBar: Bool {
        get { bool(forKey: TimerKey.showTimeRemainingInMenuBar, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: TimerKey.showTimeRemainingInMenuBar) }
    }

    /// Register the system-wide keyboard shortcut that toggles keep-awake. Defaults to on.
    static var globalShortcutEnabled: Bool {
        get { bool(forKey: TimerKey.globalShortcutEnabled, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: TimerKey.globalShortcutEnabled) }
    }

    /// Post a quiet notification when keep-awake turns off on its own
    /// (timer ended or battery auto-off). Defaults to on.
    static var notificationsEnabled: Bool {
        get { bool(forKey: TimerKey.notificationsEnabled, default: true) }
        set { UserDefaults.standard.set(newValue, forKey: TimerKey.notificationsEnabled) }
    }

    /// Reads a Bool that should default to `defaultValue` when the key has never been written.
    private static func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
    }

    // MARK: - Automatic keep-awake rules

    private enum TriggerKey {
        static let triggerAppBundleIDs = "triggerAppBundleIDs"
        static let triggerAppNames = "triggerAppNames"
        static let keepAwakeWhilePresenting = "keepAwakeWhilePresenting"
    }

    /// Bundle identifiers of apps that keep the Mac awake while they are running
    /// ("Keep Awake While Running"). Kept in the order the user added them.
    static var triggerAppBundleIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: TriggerKey.triggerAppBundleIDs) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: TriggerKey.triggerAppBundleIDs) }
    }

    /// Display names for `triggerAppBundleIDs`, keyed by bundle identifier, so the
    /// menu can name apps that are not currently running.
    static var triggerAppNames: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: TriggerKey.triggerAppNames) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: TriggerKey.triggerAppNames) }
    }

    /// Turn keep-awake on while an external, mirrored, or AirPlay display is connected.
    static var keepAwakeWhilePresenting: Bool {
        get { UserDefaults.standard.bool(forKey: TriggerKey.keepAwakeWhilePresenting) }
        set { UserDefaults.standard.set(newValue, forKey: TriggerKey.keepAwakeWhilePresenting) }
    }
}
