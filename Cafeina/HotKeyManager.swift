import AppKit
import Carbon.HIToolbox

/// Registers a system-wide keyboard shortcut using Carbon hot keys.
///
/// Carbon hot keys work inside the App Sandbox and need no Accessibility
/// permission, unlike `NSEvent` global monitors or `CGEventTap`.
@MainActor
final class HotKeyManager {
    /// Human-readable form of the shortcut (⌃⌥⌘C) for menu titles.
    static let shortcutDescription = "⌃⌥⌘C"

    /// Called on the main thread whenever the shortcut is pressed.
    var onHotKey: (() -> Void)?

    /// Whether the hot key is currently registered with the system.
    /// Registration can fail (e.g. another process already owns ⌃⌥⌘C).
    private(set) var isRegistered = false

    // Touched from the main actor and from deinit (which must release the
    // Carbon resources); `nonisolated(unsafe)` lets deinit access them.
    private nonisolated(unsafe) var hotKeyRef: EventHotKeyRef?
    private nonisolated(unsafe) var eventHandlerRef: EventHandlerRef?

    // ⌃⌥⌘C — virtual key code 8 is "C" on ANSI keyboards.
    private let keyCode = UInt32(kVK_ANSI_C)
    private let modifiers = UInt32(controlKey | optionKey | cmdKey)
    private let hotKeyID = EventHotKeyID(signature: 0x4341_4645 /* "CAFE" */, id: 1)

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    /// Registers the shortcut. Failure is logged and leaves `isRegistered` false.
    func register() {
        guard !isRegistered else {
            return
        }

        guard installEventHandlerIfNeeded() else {
            return
        }

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard status == noErr, let ref else {
            NSLog("Cafeina could not register the global shortcut \(Self.shortcutDescription) (OSStatus \(status)).")
            return
        }

        hotKeyRef = ref
        isRegistered = true
    }

    /// Unregisters the shortcut. Safe to call when not registered.
    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        isRegistered = false
    }

    /// Installs the Carbon event handler once for the app's lifetime.
    private func installEventHandlerIfNeeded() -> Bool {
        if eventHandlerRef != nil {
            return true
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()

        let handler: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else {
                return OSStatus(eventNotHandledErr)
            }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            // Carbon dispatches application-target events on the main thread.
            return MainActor.assumeIsolated {
                manager.handleHotKeyEvent(event)
            }
        }

        var handlerRef: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            userData,
            &handlerRef
        )

        guard status == noErr, let handlerRef else {
            NSLog("Cafeina could not install the global shortcut event handler (OSStatus \(status)).")
            return false
        }

        eventHandlerRef = handlerRef
        return true
    }

    private func handleHotKeyEvent(_ event: EventRef) -> OSStatus {
        var pressedID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &pressedID
        )

        guard status == noErr,
              pressedID.signature == hotKeyID.signature,
              pressedID.id == hotKeyID.id else {
            return OSStatus(eventNotHandledErr)
        }

        onHotKey?()
        return noErr
    }
}
