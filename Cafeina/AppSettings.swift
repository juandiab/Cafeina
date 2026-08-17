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
}
