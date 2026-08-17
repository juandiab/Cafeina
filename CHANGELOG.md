# Changelog

All notable changes to Cafeina are documented in this file.

## Unreleased

### Added
- Template menu-bar icon that adapts to light/dark menu bars and tinting, with distinct on (filled cup) and off (outlined cup) states
- Battery-aware auto-off options in a new Battery submenu: "Turn Off When on Battery" and "Turn Off Below 20%" (disabled on Macs without a battery)
- "Allow Display to Sleep" mode that keeps the Mac awake while letting the screen turn off

### Changed
- `scripts/build-dmg.sh` builds with `-destination 'generic/platform=macOS'` so the DMG always contains a universal (`arm64` + `x86_64`) app; the committed `dist/Cafeina.dmg` is rebuilt from 1.1
- The script no longer replaces Xcode's signature with an ad-hoc one; it keeps the automatic-signing (Apple Development) signature by default and supports optional Developer ID re-signing (`CODESIGN_IDENTITY`) and notarization + stapling (`NOTARY_PROFILE`), printing a summary (size, archs, identity, `spctl` result)
- Added App Sandbox entitlement (`Cafeina/Cafeina.entitlements`, `com.apple.security.app-sandbox`) wired into Debug and Release for App Store submission
- Fixed the Swift 6 concurrency warning in `PowerAssertionManager` by isolating it to the main actor (expiration timer now hops via `MainActor.assumeIsolated`); `AppDelegate` is explicitly `@MainActor`

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
