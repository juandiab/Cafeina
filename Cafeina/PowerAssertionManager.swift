import Foundation
import IOKit.pwr_mgt

final class PowerAssertionManager {
    private let reason = "Cafeina is keeping the Mac awake" as CFString
    private var idleSleepAssertionID: IOPMAssertionID = 0
    private var displaySleepAssertionID: IOPMAssertionID = 0

    var isEnabled: Bool {
        idleSleepAssertionID != 0 || displaySleepAssertionID != 0
    }

    func enable() {
        guard !isEnabled else {
            return
        }

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

    func disable() {
        releaseAssertions()
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
        releaseAssertions()
    }
}
