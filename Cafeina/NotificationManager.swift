import Foundation
import UserNotifications

/// Posts quiet notifications when keep-awake turns off on its own.
///
/// Authorization is requested lazily and provisionally the first time a
/// notification is about to be posted: there is no prompt, and notifications
/// are delivered silently to Notification Center until the user promotes them.
@MainActor
final class NotificationManager {
    /// Why keep-awake was turned off automatically.
    enum Reason {
        /// A timed session (`.minutes` or `.until`) reached its end.
        case timerExpired
        /// The Mac switched to battery power with "Turn Off When on Battery" enabled.
        case onBattery
        /// The battery dropped to or below the threshold with "Turn Off Below N%" enabled.
        case lowBattery(thresholdPercent: Int)

        var title: String {
            switch self {
            case .timerExpired:
                return "Cafeina turned off"
            case .onBattery:
                return "Cafeina turned off — on battery"
            case .lowBattery(let threshold):
                return "Cafeina turned off — battery below \(threshold)%"
            }
        }

        var body: String {
            switch self {
            case .timerExpired:
                return "Your keep-awake timer ended."
            case .onBattery:
                return "Keep-awake stopped because your Mac is running on battery."
            case .lowBattery(let threshold):
                return "Keep-awake stopped because the battery is at or below \(threshold)%."
            }
        }
    }

    /// Posts a "turned off" notification unless notifications are disabled in
    /// settings or the user has denied authorization.
    func notifyTurnedOff(reason: Reason) {
        guard AppSettings.notificationsEnabled else {
            return
        }

        let title = reason.title
        let body = reason.body
        Task {
            await Self.deliver(title: title, body: body)
        }
    }

    // MARK: - UserNotifications plumbing (off the main actor; only Sendable values cross)

    private nonisolated static func deliver(title: String, body: String) async {
        let center = UNUserNotificationCenter.current()

        switch await center.notificationSettings().authorizationStatus {
        case .denied:
            return
        case .notDetermined:
            let granted: Bool
            do {
                granted = try await center.requestAuthorization(options: [.alert, .sound, .provisional])
            } catch {
                NSLog("Cafeina could not request notification authorization: \(error.localizedDescription)")
                return
            }
            guard granted else {
                return
            }
        default:
            break
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            NSLog("Cafeina could not post a notification: \(error.localizedDescription)")
        }
    }
}
