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

@MainActor
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
                // The timer is scheduled on the main run loop, so it always fires on the main thread.
                MainActor.assumeIsolated {
                    self?.disable()
                }
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
        let idleResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoIdleSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &idleSleepAssertionID
        )

        if idleResult != kIOReturnSuccess {
            idleSleepAssertionID = 0
        }

        let displayResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &displaySleepAssertionID
        )

        if displayResult != kIOReturnSuccess {
            displaySleepAssertionID = 0
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
        // deinit is nonisolated, so it may only read Sendable stored properties directly
        // (it cannot call the main-actor-isolated helpers above or touch the Timer).
        // A pending expiration timer only holds `self` weakly, so it fires as a no-op.
        if idleSleepAssertionID != 0 {
            IOPMAssertionRelease(idleSleepAssertionID)
        }

        if displaySleepAssertionID != 0 {
            IOPMAssertionRelease(displaySleepAssertionID)
        }
    }
}
