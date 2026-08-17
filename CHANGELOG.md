# Changelog

All notable changes to Cafeina are documented in this file.

## Unreleased

### Added
- Template menu-bar icon that adapts to light/dark menu bars and tinting, with distinct on (filled cup) and off (outlined cup) states
- Battery-aware auto-off options in a new Battery submenu: "Turn Off When on Battery" and "Turn Off Below 20%" (disabled on Macs without a battery)
- "Allow Display to Sleep" mode that keeps the Mac awake while letting the screen turn off
- Shortcuts & Siri support via App Intents: Keep Mac Awake (with duration), Turn Off, Toggle, Get Status; Focus-mode automations (see `docs/SHORTCUTS.md`)
- "Until a Time…" keep-awake mode: pick a wall-clock time in a small panel and Cafeina stays on until the next occurrence of that time (today, or tomorrow if it has already passed)
- Menu-bar countdown: the remaining time of a timed session ("42m", "1h 05m") is shown next to the cup icon; toggle with "Show Time Remaining in Menu Bar"
- Global keyboard shortcut ⌃⌥⌘C toggles keep-awake from any app (Carbon hot key — sandbox-safe, no Accessibility permission); toggle with "Global Shortcut ⌃⌥⌘C"
- Quiet notifications (provisional authorization, no prompt) when Cafeina turns off automatically — timer ended, or battery auto-off; toggle with "Notify When Turned Off Automatically"

### Changed
- `scripts/build-dmg.sh` builds with `-destination 'generic/platform=macOS'` so the DMG always contains a universal (`arm64` + `x86_64`) app; the committed `dist/Cafeina.dmg` is rebuilt from 1.1
- The script no longer replaces Xcode's signature with an ad-hoc one; it keeps the automatic-signing (Apple Development) signature by default and supports optional Developer ID re-signing (`CODESIGN_IDENTITY`) and notarization + stapling (`NOTARY_PROFILE`), printing a summary (size, archs, identity, `spctl` result)
- Added App Sandbox entitlement (`Cafeina/Cafeina.entitlements`, `com.apple.security.app-sandbox`) wired into Debug and Release for App Store submission
- Fixed the Swift 6 concurrency warning in `PowerAssertionManager` by isolating it to the main actor (expiration timer now hops via `MainActor.assumeIsolated`); `AppDelegate` is explicitly `@MainActor`

### Fixed
- Relaunching Cafeina (Dock, Finder, Spotlight) now opens the About window instead of showing nothing
- Control-click on the menu bar icon opens the menu, same as right-click; tooltip and first-launch hint updated to say so
- Open at Login: when the login item requires approval, the menu item now opens System Settings › Login Items; if enabling/disabling fails, an alert explains why with a shortcut to Login Items
- First-launch hint now activates the app so the alert appears in front
- "Website" link (About window, README) points to https://www.nexxus-tech.com/cafeina
- `Info.plist` declares `ITSAppUsesNonExemptEncryption=false` and reads its version from `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`
- Added a privacy manifest (`PrivacyInfo.xcprivacy`: no tracking, no collected data, UserDefaults reason `CA92.1`), bundled in Resources
- About window shows the build-setting-driven version (1.1 (2))
- `docs/APP_STORE_AUDIT.md` gained a Status section listing what this branch fixes

## 1.1.0 — 2026-08-17

### Added
- Timed keep-awake modes: 30 minutes, 1 hour, 2 hours, or indefinitely
- About window with version, copyright, Privacy Policy, Support, and Website links
- Menu items for Privacy Policy and Support (`support@nexxus-tech.com`)
- First-launch hint explaining the menu bar cup icon
- App category (Utilities), display name, and human-readable copyright

### Changed
- Minimum macOS version lowered from 26.0 to **13.0**
- Release builds are universal (`arm64` + `x86_64`)
- Signing uses personal Apple Development team (`SR8DQF26N7`) with hardened runtime
- Bundle ID remains personal: `com.juampa.Cafeina`
- Marketing version **1.1** (build **2**)

### Notes
- Cafeina is not affiliated with Caffeine or any similarly named apps
- Privacy policy URL: https://www.nexxus-tech.com/cafeina/privacy
- App Store packaging and notarization are still pending

## 1.0.0

- Initial menu bar keep-awake app with Open at Login and downloadable DMG
