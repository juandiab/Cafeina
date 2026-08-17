# Cafeina

Cafeina is a native macOS menu bar app that keeps your Mac awake while enabled.

**Version 1.1** · **Requires macOS 13.0 or later**

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## Features

- Toggle keep-awake from the menu bar cup icon (filled when on, outlined when off; matches light/dark menu bars)
- Timed modes: 30 minutes, 1 hour, 2 hours, indefinitely, or until a time of day you pick
- Menu-bar countdown showing the time remaining in a timed session (can be turned off)
- Global keyboard shortcut ⌃⌥⌘C to toggle keep-awake from any app (can be turned off)
- Quiet notifications when Cafeina turns itself off (timer ended or battery auto-off; can be turned off)
- Battery-aware auto-off: turn off when on battery, or below 20%
- Allow Display to Sleep mode: keeps the Mac awake but lets the screen turn off
- Optional Open at Login
- About, Privacy Policy, and Support links in the menu

## Download

Download the latest DMG from this repository:

[Download Cafeina.dmg](https://github.com/juandiab/Cafeina/raw/main/dist/Cafeina.dmg)

## Support

- Email: [support@nexxus-tech.com](mailto:support@nexxus-tech.com)
- Website: [www.nexxus-tech.com](https://www.nexxus-tech.com)
- Privacy: [www.nexxus-tech.com/cafeina/privacy](https://www.nexxus-tech.com/cafeina/privacy)

## Build

Open `Cafeina.xcodeproj` in Xcode, or build from the command line:

```bash
xcodebuild -project Cafeina.xcodeproj -scheme Cafeina -configuration Release build
```

## Create the DMG

The packaging script builds a universal (`arm64` + `x86_64`) Release app, stages `Cafeina.app`, and creates `dist/Cafeina.dmg`. It prints a summary (size, architectures, signing identity, Gatekeeper assessment) when done.

```bash
chmod +x scripts/build-dmg.sh
./scripts/build-dmg.sh
```

By default the app keeps the signature produced by Xcode's automatic signing (Apple Development). That is fine for local testing, but the DMG will **not** pass Gatekeeper on other Macs until it is signed with a Developer ID certificate and notarized. Two optional environment variables enable that:

| Variable | Effect |
| --- | --- |
| `CODESIGN_IDENTITY` | Re-signs the app with the given identity (hardened runtime, secure timestamp, `Cafeina/Cafeina.entitlements`). Use your `Developer ID Application: Name (TEAMID)` identity. |
| `NOTARY_PROFILE` | Name of a `xcrun notarytool store-credentials` keychain profile. When set, the DMG is submitted for notarization (`--wait`) and stapled. Requires `CODESIGN_IDENTITY`. |

```bash
# One-time: store App Store Connect credentials in the keychain
xcrun notarytool store-credentials cafeina-notary \
  --apple-id you@example.com --team-id TEAMID --password <app-specific-password>

# Signed + notarized DMG
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE=cafeina-notary \
./scripts/build-dmg.sh
```

The app is sandboxed (`com.apple.security.app-sandbox`) via `Cafeina/Cafeina.entitlements`, which is also what the App Store submission needs.

Cafeina is an independent app and is not affiliated with Caffeine or any similarly named products.
