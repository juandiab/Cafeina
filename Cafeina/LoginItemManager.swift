import AppKit
import Foundation
import ServiceManagement

@MainActor
final class LoginItemManager {
    var opensAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    var menuItemState: NSControl.StateValue {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .on
        case .requiresApproval:
            return .mixed
        default:
            return .off
        }
    }

    func toggleOpenAtLogin() {
        setOpenAtLogin(!opensAtLogin)
    }

    private func setOpenAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                guard SMAppService.mainApp.status != .enabled else {
                    return
                }
                try SMAppService.mainApp.register()
            } else {
                guard SMAppService.mainApp.status == .enabled else {
                    return
                }
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Cafeina failed to update Open at Login: \(error.localizedDescription)")
        }
    }
}
