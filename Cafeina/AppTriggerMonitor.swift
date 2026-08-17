import AppKit

/// Tracks the user's "Keep Awake While Running" apps and whether any of them is
/// currently running.
///
/// The set of trigger apps is persisted in `AppSettings` (bundle identifiers plus a
/// display-name cache). Running state is re-evaluated on init and on every
/// `NSWorkspace` app launch/terminate notification; `onChange` fires whenever the
/// set of running trigger apps changes.
@MainActor
final class AppTriggerMonitor {
    /// Bundle identifiers of the configured trigger apps, in the order they were added.
    private(set) var triggerBundleIDs: [String] = AppSettings.triggerAppBundleIDs
    private var triggerNames: [String: String] = AppSettings.triggerAppNames

    /// Bundle identifiers of configured trigger apps that are running right now.
    private(set) var runningTriggerBundleIDs: [String] = []

    /// Called on the main thread whenever the set of running trigger apps changes,
    /// including when the trigger list itself is edited.
    var onChange: (() -> Void)?

    // Only touched from the main actor and from deinit (which needs them to
    // unregister); `nonisolated(unsafe)` lets deinit access them.
    private nonisolated(unsafe) var observers: [NSObjectProtocol] = []

    var isAnyTriggerAppRunning: Bool {
        !runningTriggerBundleIDs.isEmpty
    }

    /// Display names of the running trigger apps, sorted alphabetically.
    var runningTriggerAppNames: [String] {
        runningTriggerBundleIDs
            .map { name(forBundleID: $0) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    init() {
        refresh()
        startObserving()
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        for observer in observers {
            center.removeObserver(observer)
        }
    }

    // MARK: - Trigger list

    func contains(bundleID: String) -> Bool {
        triggerBundleIDs.contains(bundleID)
    }

    /// Display name for a configured trigger app (falls back to the running app's
    /// name, then to the bundle identifier).
    func name(forBundleID bundleID: String) -> String {
        if let name = triggerNames[bundleID], !name.isEmpty {
            return name
        }
        if let name = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == bundleID })?.localizedName, !name.isEmpty {
            return name
        }
        return bundleID
    }

    func add(bundleID: String, name: String) {
        guard !bundleID.isEmpty else {
            return
        }
        if !triggerBundleIDs.contains(bundleID) {
            triggerBundleIDs.append(bundleID)
        }
        triggerNames[bundleID] = name
        persist()
        refreshAndNotifyIfChanged()
    }

    func remove(bundleID: String) {
        triggerBundleIDs.removeAll { $0 == bundleID }
        triggerNames[bundleID] = nil
        persist()
        refreshAndNotifyIfChanged()
    }

    private func persist() {
        AppSettings.triggerAppBundleIDs = triggerBundleIDs
        AppSettings.triggerAppNames = triggerNames
    }

    // MARK: - Running state

    private func startObserving() {
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification
        ]
        for notificationName in names {
            let observer = center.addObserver(forName: notificationName, object: nil, queue: .main) { [weak self] _ in
                // Delivered on the main queue, so this is on the main actor.
                MainActor.assumeIsolated {
                    self?.refreshAndNotifyIfChanged()
                }
            }
            observers.append(observer)
        }
    }

    private func refreshAndNotifyIfChanged() {
        let previous = runningTriggerBundleIDs
        refresh()
        if runningTriggerBundleIDs != previous {
            onChange?()
        }
    }

    private func refresh() {
        let triggers = Set(triggerBundleIDs)
        guard !triggers.isEmpty else {
            runningTriggerBundleIDs = []
            return
        }

        var running: [String] = []
        for app in NSWorkspace.shared.runningApplications where !app.isTerminated {
            if let bundleID = app.bundleIdentifier, triggers.contains(bundleID), !running.contains(bundleID) {
                running.append(bundleID)
            }
        }
        runningTriggerBundleIDs = running.sorted()
    }
}
