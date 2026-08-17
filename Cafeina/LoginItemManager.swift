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
        // The user must approve the login item in System Settings; re-registering
        // does nothing here, so take them straight to Login Items instead.
        if SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
            return
        }
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
            showUpdateFailedAlert(error)
        }
    }

    private func showUpdateFailedAlert(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Couldn't update Open at Login"
        alert.informativeText = "\(error.localizedDescription)\n\nYou can manage Cafeina under Login Items in System Settings."
        alert.addButton(withTitle: "Open Login Items")
        alert.addButton(withTitle: "OK")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
