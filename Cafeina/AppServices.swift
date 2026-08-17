import AppKit

/// Main-actor access to the app's long-lived services for callers that don't
/// receive them by injection (e.g. App Intents invoked from Shortcuts/Siri).
@MainActor
enum AppServices {
    static var powerAssertionManager: PowerAssertionManager? {
        (NSApp.delegate as? AppDelegate)?.powerAssertionManager
    }
}
