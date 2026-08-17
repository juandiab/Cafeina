import AppKit
import CoreGraphics

/// Observes the connected displays and reports whether the Mac looks like it is
/// "presenting": more than one screen, a mirrored screen, or an AirPlay display.
@MainActor
final class DisplayMonitor {
    private(set) var isPresenting = false

    /// Called on the main thread whenever `isPresenting` changes.
    var onChange: (() -> Void)?

    // Only touched from the main actor and from deinit (which needs it to
    // unregister); `nonisolated(unsafe)` lets deinit access it.
    private nonisolated(unsafe) var observer: NSObjectProtocol?

    init() {
        refresh()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Delivered on the main queue, so this is on the main actor.
            MainActor.assumeIsolated {
                self?.handleScreenParametersChange()
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func handleScreenParametersChange() {
        let wasPresenting = isPresenting
        refresh()
        if isPresenting != wasPresenting {
            onChange?()
        }
    }

    private func refresh() {
        isPresenting = Self.detectPresenting()
    }

    private static func detectPresenting() -> Bool {
        let screens = NSScreen.screens
        if screens.count > 1 {
            return true
        }

        for screen in screens {
            if screen.localizedName.localizedCaseInsensitiveContains("AirPlay") {
                return true
            }
            guard let displayID = displayID(for: screen) else {
                continue
            }
            if CGDisplayIsInMirrorSet(displayID) != 0 || CGDisplayIsAlwaysInMirrorSet(displayID) != 0 {
                return true
            }
        }

        return false
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value
    }
}
