import Foundation
import IOKit.pwr_mgt

enum KeepAwakeDuration: Equatable {
    case indefinite
    case minutes(Int)

    var menuTitle: String {
        switch self {
        case .indefinite:
            return "Indefinitely"
        case .minutes(let minutes) where minutes < 60:
            return "\(minutes) Minutes"
        case .minutes(let minutes) where minutes % 60 == 0:
            let hours = minutes / 60
            return hours == 1 ? "1 Hour" : "\(hours) Hours"
        case .minutes(let minutes):
            return "\(minutes) Minutes"
        }
    }

    var statusSuffix: String {
        switch self {
        case .indefinite:
            return "indefinitely"
        case .minutes(let minutes) where minutes < 60:
            return "for \(minutes) min"
        case .minutes(let minutes) where minutes % 60 == 0:
            let hours = minutes / 60
            return hours == 1 ? "for 1 hour" : "for \(hours) hours"
        case .minutes(let minutes):
            return "for \(minutes) min"
        }
    }
}

final class PowerAssertionManager {
    private let reason = "Cafeina is keeping the Mac awake" as CFString
    private var idleSleepAssertionID: IOPMAssertionID = 0
    private var displaySleepAssertionID: IOPMAssertionID = 0
    private var expirationTimer: Timer?
    private(set) var activeDuration: KeepAwakeDuration?
    private(set) var expiresAt: Date?

    var onStateChange: (() -> Void)?

    var isEnabled: Bool {
        idleSleepAssertionID != 0 || displaySleepAssertionID != 0
    }

    /// When true, only system idle sleep is prevented and the display may sleep.
    /// Toggling while keep-awake is active re-creates the assertions in place,
    /// preserving the current duration and expiry.
    var allowDisplaySleep: Bool {
        get { AppSettings.allowDisplaySleep }
        set {
            AppSettings.allowDisplaySleep = newValue
            recreateAssertionsIfEnabled()
        }
    }

    func enable(for duration: KeepAwakeDuration) {
        disable(notify: false)
        createAssertions()

        guard isEnabled else {
            activeDuration = nil
            expiresAt = nil
            onStateChange?()
            return
        }

        activeDuration = duration

        switch duration {
        case .indefinite:
            expiresAt = nil
        case .minutes(let minutes):
            let expiration = Date().addingTimeInterval(TimeInterval(minutes * 60))
            expiresAt = expiration
            let timer = Timer(fire: expiration, interval: 0, repeats: false) { [weak self] _ in
                self?.disable()
            }
            RunLoop.main.add(timer, forMode: .common)
            expirationTimer = timer
        }

        onStateChange?()
    }

    func disable() {
        disable(notify: true)
    }

    private func disable(notify: Bool) {
        expirationTimer?.invalidate()
        expirationTimer = nil
        activeDuration = nil
        expiresAt = nil
        releaseAssertions()

        if notify {
            onStateChange?()
        }
    }

    private func createAssertions() {
        idleSleepAssertionID = createAssertion(type: kIOPMAssertionTypeNoIdleSleep)
        displaySleepAssertionID = allowDisplaySleep
            ? 0
            : createAssertion(type: kIOPMAssertionTypeNoDisplaySleep)
    }

    private func createAssertion(type: String) -> IOPMAssertionID {
        var assertionID: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        return result == kIOReturnSuccess ? assertionID : 0
    }

    private func recreateAssertionsIfEnabled() {
        guard isEnabled else {
            return
        }

        releaseAssertions()
        createAssertions()

        if !isEnabled {
            disable()
        }
    }

    private func releaseAssertions() {
        if idleSleepAssertionID != 0 {
            IOPMAssertionRelease(idleSleepAssertionID)
            idleSleepAssertionID = 0
        }

        if displaySleepAssertionID != 0 {
            IOPMAssertionRelease(displaySleepAssertionID)
            displaySleepAssertionID = 0
        }
    }

    deinit {
        expirationTimer?.invalidate()
        releaseAssertions()
    }
}
