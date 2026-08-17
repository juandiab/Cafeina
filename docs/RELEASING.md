# Releasing Cafeina

Two channels: **Mac App Store** (free) and **direct download** (notarized DMG on GitHub, later Homebrew).

## Facts

| | |
|---|---|
| Bundle ID | `com.juampa.Cafeina` (App ID registered in the developer portal) |
| Team | `SR8DQF26N7` — Juan Pablo Otalvaro A (personal, paid) |
| App Store Connect | app **"Cafeina – Keep Awake"** (Apple ID 6802437332, SKU `cafeina-mac`) |
| Version source of truth | `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `Cafeina.xcodeproj` (Info.plist reads them) |
| Signing | Automatic. Developer ID Application is **cloud-managed** (created via Xcode). Sandbox + hardened runtime on. |
| Privacy | Data Not Collected. Policy: https://www.nexxus-tech.com/cafeina/privacy |
| Support / marketing URL | https://www.nexxus-tech.com/cafeina · support@nexxus-tech.com |

## 1. Bump the version

1. Edit `MARKETING_VERSION` (e.g. `1.3`) and `CURRENT_PROJECT_VERSION` (monotonic build number) in the pbxproj (both Debug/Release configs).
2. Retitle `## Unreleased` in `CHANGELOG.md`, update the version line in `README.md`.
3. Commit, tag `vX.Y.Z`, push `main` and tags.

## 2. App Store

Xcode → Product → **Archive** → Organizer → **Distribute App** → *App Store Connect* → Upload (defaults). Xcode manages the Apple Distribution / Mac Installer certificates.

Then in App Store Connect → the app → macOS version:
- Version string must match `MARKETING_VERSION`.
- Select the uploaded build; screenshots/description/keywords already exist (see `design/appstore/`).
- **Add for Review** → Submit.

Reviewer notes and metadata copy: `docs/APP_STORE_AUDIT.md`. Keep the words "Caffeine"/"Amphetamine" out of all metadata.

`xcodebuild -exportArchive -allowProvisioningUpdates` from a terminal may fail with "No Accounts" (xcodebuild can't read Xcode's account token). Use the Xcode GUI, or an App Store Connect API key with `-authenticationKeyPath/-authenticationKeyID/-authenticationKeyIssuerID`.

## 3. Direct download (DMG)

Preferred (cloud-managed Developer ID + notarization via `notarytool`):

```bash
DEVELOPER_ID_TEAM=SR8DQF26N7 NOTARY_PROFILE=cafeina-notary ./scripts/build-dmg.sh
```

- `NOTARY_PROFILE` is created once with `xcrun notarytool store-credentials cafeina-notary --key ~/.private_keys/AuthKey_<ID>.p8 --key-id <ID> --issuer <ISSUER>` (App Store Connect API key) or `--apple-id otalvaroj@hotmail.com --team-id SR8DQF26N7` + an app-specific password generated while signed in as that Apple ID.
- Without `NOTARY_PROFILE` the DMG is signed but Gatekeeper rejects it on other Macs.
- Alternative: Xcode Organizer → Distribute App → *Direct Distribution* → Export Notarized App, then `hdiutil create -volname Cafeina -srcfolder <folder-with-app> -format UDZO dist/Cafeina.dmg`.

Commit `dist/Cafeina.dmg` (the README download link points at it).

## 4. Assets

- App icon: `Cafeina/Assets.xcassets/AppIcon.appiconset/` (source SVG + renders in `design/icon/`, standalone `design/icon/Cafeina-icon-1024.png`).
- App Store screenshots: `design/appstore/` (re-render marketing boards with `swift design/appstore/render-marketing.swift <icon1024> <menu-shot> <outdir>`).

## 5. Checklist before submitting

- [ ] Release build, 0 warnings, launches; `pmset -g assertions` shows the assertion when on
- [ ] Version/build bumped, CHANGELOG/README updated, tag pushed
- [ ] Sandbox entitlement present (`codesign -d --entitlements :- Cafeina.app`)
- [ ] ASC version string == MARKETING_VERSION; build selected; screenshots present
- [ ] Privacy URL still resolves; support email works
