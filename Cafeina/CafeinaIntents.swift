import AppIntents
import AppKit

// MARK: - Shared helpers

enum CafeinaIntentError: Error, LocalizedError, CustomLocalizedStringResourceConvertible {
    case notReady

    var errorDescription: String? {
        switch self {
        case .notReady:
            return "Cafeina isn't ready yet. Open Cafeina and try again."
        }
    }

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notReady:
            return "Cafeina isn't ready yet. Open Cafeina and try again."
        }
    }
}

@MainActor
private func requirePowerAssertionManager() throws -> PowerAssertionManager {
    guard let manager = AppServices.powerAssertionManager else {
        throw CafeinaIntentError.notReady
    }
    return manager
}

@MainActor
private func statusMessage(for manager: PowerAssertionManager) -> String {
    guard manager.isEnabled else {
        return "Cafeina is off."
    }

    if let expiresAt = manager.expiresAt {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "Cafeina is keeping your Mac awake until \(formatter.string(from: expiresAt))."
    }

    if let duration = manager.activeDuration {
        return "Cafeina is keeping your Mac awake \(duration.statusSuffix)."
    }

    return "Cafeina is keeping your Mac awake."
}

// MARK: - Duration enum

enum KeepAwakeDurationOption: String, AppEnum {
    case thirtyMinutes
    case oneHour
    case twoHours
    case indefinitely

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Duration"

    static let caseDisplayRepresentations: [KeepAwakeDurationOption: DisplayRepresentation] = [
        .thirtyMinutes: "30 Minutes",
        .oneHour: "1 Hour",
        .twoHours: "2 Hours",
        .indefinitely: "Indefinitely"
    ]

    var keepAwakeDuration: KeepAwakeDuration {
        switch self {
        case .thirtyMinutes:
            return .minutes(30)
        case .oneHour:
            return .minutes(60)
        case .twoHours:
            return .minutes(120)
        case .indefinitely:
            return .indefinite
        }
    }
}

// MARK: - Intents

struct KeepAwakeIntent: AppIntent {
    static let title: LocalizedStringResource = "Keep Mac Awake"
    static let description = IntentDescription(
        "Turns on Cafeina so your Mac stays awake for the chosen duration."
    )
    static let openAppWhenRun = false

    @Parameter(title: "Duration", default: .indefinitely)
    var duration: KeepAwakeDurationOption

    static var parameterSummary: some ParameterSummary {
        Summary("Keep Mac awake \(\.$duration)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = try requirePowerAssertionManager()
        manager.enable(for: duration.keepAwakeDuration)
        return .result(dialog: "\(statusMessage(for: manager))")
    }
}

struct TurnOffKeepAwakeIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn Off Cafeina"
    static let description = IntentDescription(
        "Turns off Cafeina and lets your Mac sleep normally."
    )
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = try requirePowerAssertionManager()
        manager.disable()
        return .result(dialog: "Cafeina is off.")
    }
}

struct ToggleKeepAwakeIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Cafeina"
    static let description = IntentDescription(
        "Turns Cafeina off if it is on, or on indefinitely if it is off."
    )
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = try requirePowerAssertionManager()
        if manager.isEnabled {
            manager.disable()
        } else {
            manager.enable(for: .indefinite)
        }
        return .result(dialog: "\(statusMessage(for: manager))")
    }
}

struct GetKeepAwakeStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Cafeina Status"
    static let description = IntentDescription(
        "Returns whether Cafeina is currently keeping your Mac awake."
    )
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
        let manager = try requirePowerAssertionManager()
        return .result(value: manager.isEnabled, dialog: "\(statusMessage(for: manager))")
    }
}

// MARK: - App Shortcuts

struct CafeinaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: KeepAwakeIntent(),
            phrases: [
                "Keep my Mac awake with \(.applicationName)",
                "Turn on \(.applicationName)"
            ],
            shortTitle: "Keep Mac Awake",
            systemImageName: "cup.and.saucer.fill"
        )
        AppShortcut(
            intent: TurnOffKeepAwakeIntent(),
            phrases: [
                "Turn off \(.applicationName)"
            ],
            shortTitle: "Turn Off",
            systemImageName: "cup.and.saucer"
        )
        AppShortcut(
            intent: ToggleKeepAwakeIntent(),
            phrases: [
                "Toggle \(.applicationName)"
            ],
            shortTitle: "Toggle",
            systemImageName: "arrow.triangle.2.circlepath"
        )
        AppShortcut(
            intent: GetKeepAwakeStatusIntent(),
            phrases: [
                "Is \(.applicationName) on"
            ],
            shortTitle: "Status",
            systemImageName: "questionmark.circle"
        )
    }
}
