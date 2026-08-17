# Cafeina — Mac App Store Review Audit

Audited read-only at `main` @ 3f5ec3b (2026-08-17). Items marked ✅ are being fixed in the current work rounds.

## Executive summary
- Menu-bar accessory app (`LSUIElement`) holding NoIdleSleep + NoDisplaySleep IOPM assertions; left-click toggles, right-click menu with timers, Open at Login, About, Privacy, Support.
- **Top approval risks:** (1) no App Sandbox entitlement — upload rejected outright (ITMS-90296 / 2.4.5(i)) ✅; (2) reviewability gaps — nothing re-surfaces on relaunch, Control-click toggles instead of opening the menu, Open-at-Login `.requiresApproval` dead-ends ✅; (3) name ≈ "Caffeine" — keep "Caffeine" out of ASC metadata (2.3.7 / 4.1).
- **Fast wins:** `ITSAppUsesNonExemptEncryption=false`; `SMAppService.openSystemSettingsLoginItems()` on `.requiresApproval`; `applicationShouldHandleReopen`; point Website/Support URL to `/cafeina` ✅.
- **Verified good:** privacy policy URL renders correctly in a browser (client-side rendered SPA); zero networking code → nutrition label = "Data Not Collected"; Open at Login is opt-in (2.4.5(iv)); universal Release build; hardened runtime on; min-OS 13.0 is honest (all APIs ≤ 13.0).
- **4.2 minimum-functionality risk: low (~10%)** — Amphetamine, Theine, Lungo, Caffeinated and two MAS apps literally named "Caffeine" ship the same core.

## Risk register

| Pri | Area | Finding | Recommendation |
|---|---|---|---|
| P0 | Entitlements | No App Sandbox entitlement | Add `com.apple.security.app-sandbox=true` (all used APIs work sandboxed) ✅ |
| P0 | Metadata 5.1.1 | Privacy URL is a SPA route; raw HTML is the homepage shell | Acceptable (renders in Safari). Optionally prerender static HTML + per-route `<title>` |
| P1 | Reviewability | Relaunch shows nothing; hint appears once | Implement `applicationShouldHandleReopen` → open About / re-show hint ✅ |
| P1 | UX | Control-click toggles instead of opening the menu; VoiceOver can't reach Quit/About | Treat ⌃-click as menu ✅ |
| P1 | UX | `.requiresApproval` login-item state dead-ends (mixed dash, error only NSLog'd) | Call `openSystemSettingsLoginItems()`; show NSAlert on error ✅ |
| P2 | Content 4.1/2.3.7 | Name ≈ Caffeine; generic cup icon | Never use "Caffeine"/"Amphetamine" in App Name/Subtitle/Keywords/Description; distinctive icon ✅ |
| P2 | UX | First-launch `NSAlert.runModal` without activating; blocks status-item clicks | `NSApp.activate(ignoringOtherApps:)` before runModal, or non-blocking window ✅ |
| P2 | Metadata | "Website" link opens the enterprise WAF/NetScaler homepage | Use `https://www.nexxus-tech.com/cafeina` for Support/Marketing URL and About "Website" ✅ |
| P2 | Privacy | No `PrivacyInfo.xcprivacy` (UserDefaults → reason CA92.1) | Add manifest: tracking=false, no collected types, `CA92.1` ✅ |
| P3 | Metadata | Missing `ITSAppUsesNonExemptEncryption` | Add `<false/>` ✅ |
| P3 | Design | Non-template colored menu-bar icon | Template `cup.and.saucer.fill` (on) / `cup.and.saucer` (off) ✅ |
| P3 | Hygiene | Committed DMG is stale 1.0 (macOS 26 min, arm64-only, ad-hoc) | Rebuild + notarize ✅ |
| P3 | Build | Version hard-coded in Info.plist and build settings | Use `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` ✅ |

## App Store Connect metadata
- App Name: "Cafeina" (check availability; fallback "Cafeina – Keep Mac Awake"). Category: Utilities. Age rating: answer "None" → 4+. Price: Free.
- Privacy nutrition label: **Data Not Collected**. Privacy URL: https://www.nexxus-tech.com/cafeina/privacy. Support/Marketing URL: https://www.nexxus-tech.com/cafeina.
- Screenshots: ≥1 at 1280×800 / 1440×900 / 2560×1600 / 2880×1800 showing the menu bar with the open menu, plus the About window (real UI only, 2.3.3).
- Keywords: keep awake, sleep, caffeine-free wording — do NOT include competitor names.

## Reviewer notes (paste into App Store Connect)
> Cafeina is a menu-bar-only utility (no Dock icon, no main window). After launch, look for the coffee-cup icon in the menu bar near the clock; a one-time alert also points to it. Left-click the icon toggles keep-awake (filled cup = on, outline = off; hover for tooltip). Right-click or Control-click opens the menu: Keep Awake ▸ 30 min / 1 h / 2 h / Indefinitely, Turn Off, Allow Display to Sleep, Battery options, Open at Login (opt-in; uses SMAppService), About Cafeina, Privacy Policy, Support, Quit. Verify keep-awake in Terminal: `pmset -g assertions` (shows "Cafeina is keeping the Mac awake"). No account, no network access, no data collection, no in-app purchases. Privacy policy: https://www.nexxus-tech.com/cafeina/privacy. Cafeina is an independent app.

## Status

Fixed on `agent/polish` (verified: Release universal build, zero warnings; bundle shows 1.1 / 2, `ITSAppUsesNonExemptEncryption=false`, `Resources/PrivacyInfo.xcprivacy` present):

- P1 Reviewability — `applicationShouldHandleReopen` opens the About window when no window is visible.
- P1 UX — Control-click on the status item opens the menu (same as right-click); tooltip and first-launch hint say so.
- P1 UX — Open at Login: `.requiresApproval` jumps to System Settings › Login Items; register/unregister errors show an alert with an "Open Login Items" button.
- P2 UX — First-launch hint activates the app before `runModal()`.
- P2 Metadata — Website link (About + README) is `https://www.nexxus-tech.com/cafeina`.
- P2 Privacy — `Cafeina/PrivacyInfo.xcprivacy` added (tracking=false, no collected data, UserDefaults `CA92.1`) and copied into the bundle.
- P3 Metadata — `ITSAppUsesNonExemptEncryption=false` in Info.plist.
- P3 Build — Info.plist versions are `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`.

Handled elsewhere: P0 Sandbox, P3 template icon, P3 DMG rebuild (`main` / other branches). Remaining (ASC-side, no code): P0/P2 metadata wording and privacy-URL prerender.
