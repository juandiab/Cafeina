import Foundation
import IOKit.ps

/// Observes the Mac's power source (AC vs. battery) and battery charge level.
///
/// Desktop Macs without a battery report `isOnBattery == false` and
/// `batteryPercent == nil`.
@MainActor
final class PowerSourceMonitor {
    private(set) var isOnBattery = false
    private(set) var batteryPercent: Int?

    /// Called on the main thread whenever the power source state changes.
    var onChange: (() -> Void)?

    // Only touched from the main actor and from deinit (which needs it to
    // remove the source); `nonisolated(unsafe)` lets deinit access it.
    private nonisolated(unsafe) var runLoopSource: CFRunLoopSource?

    init() {
        refresh()
        startObserving()
    }

    deinit {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CFRunLoopSourceInvalidate(runLoopSource)
        }
    }

    private func startObserving() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else {
                return
            }
            let monitor = Unmanaged<PowerSourceMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated {
                monitor.handlePowerSourceChange()
            }
        }

        guard let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() else {
            return
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        runLoopSource = source
    }

    private func handlePowerSourceChange() {
        refresh()
        onChange?()
    }

    private func refresh() {
        guard let battery = internalBatteryDescription() else {
            isOnBattery = false
            batteryPercent = nil
            return
        }

        let state = battery[kIOPSPowerSourceStateKey] as? String
        isOnBattery = state == kIOPSBatteryPowerValue
        batteryPercent = percent(from: battery)
    }

    private func internalBatteryDescription() -> [String: Any]? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?
                .takeUnretainedValue() as? [String: Any] else {
                continue
            }
            if description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType {
                return description
            }
        }

        return nil
    }

    private func percent(from battery: [String: Any]) -> Int? {
        guard let current = battery[kIOPSCurrentCapacityKey] as? Int,
              let max = battery[kIOPSMaxCapacityKey] as? Int,
              max > 0 else {
            return nil
        }
        return Int((Double(current) / Double(max) * 100).rounded())
    }
}
