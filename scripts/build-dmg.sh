#!/usr/bin/env bash
#
# Builds a universal (arm64 + x86_64) Release build of Cafeina and packages it
# into dist/Cafeina.dmg.
#
# Optional environment variables:
#
#   DEVELOPER_ID_TEAM  Team ID (e.g. SR8DQF26N7). When set, the app is built via
#                      `xcodebuild archive` + `-exportArchive` (method
#                      developer-id, automatic signing, -allowProvisioningUpdates)
#                      so Xcode's cloud-managed "Developer ID Application"
#                      certificate is used. This is the recommended path and
#                      needs no local certificate. Requires being signed in to
#                      the developer account in Xcode > Settings > Accounts.
#
#   CODESIGN_IDENTITY  (Alternative to DEVELOPER_ID_TEAM.) Re-sign the app with a
#                      local identity before packaging,
#                      e.g. "Developer ID Application: Name (TEAMID)".
#                      When unset, the signature produced by xcodebuild
#                      (Apple Development via automatic signing) is kept.
#
#   NOTARY_PROFILE     Name of a keychain profile created with
#                      `xcrun notarytool store-credentials <name>`. When set,
#                      the DMG is submitted for notarization and stapled.
#                      Requires DEVELOPER_ID_TEAM or a Developer ID
#                      CODESIGN_IDENTITY.
#
set -euo pipefail

APP_NAME="Cafeina"
PROJECT_NAME="Cafeina.xcodeproj"
SCHEME="Cafeina"
CONFIGURATION="Release"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${TMPDIR:-/private/tmp}/CafeinaDmgBuild"
DERIVED_DATA_DIR="$BUILD_ROOT/DerivedData"
STAGING_DIR="$BUILD_ROOT/dmg-staging"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
ENTITLEMENTS_PATH="$ROOT_DIR/Cafeina/Cafeina.entitlements"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
DEVELOPER_ID_TEAM="${DEVELOPER_ID_TEAM:-}"
ARCHIVE_PATH="$BUILD_ROOT/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_ROOT/export"

log() {
  printf '\n==> %s\n' "$*"
}

warn() {
  printf '\nWARNING: %s\n' "$*" >&2
}

if [ -n "$NOTARY_PROFILE" ] && [ -z "$CODESIGN_IDENTITY" ] && [ -z "$DEVELOPER_ID_TEAM" ]; then
  echo "error: NOTARY_PROFILE is set but neither DEVELOPER_ID_TEAM nor CODESIGN_IDENTITY is." >&2
  echo "       Notarization requires a \"Developer ID Application\" signature." >&2
  exit 1
fi
if [ -n "$DEVELOPER_ID_TEAM" ] && [ -n "$CODESIGN_IDENTITY" ]; then
  echo "error: set either DEVELOPER_ID_TEAM (archive/export) or CODESIGN_IDENTITY (local re-sign), not both." >&2
  exit 1
fi

if [ ! -f "$ENTITLEMENTS_PATH" ]; then
  echo "error: entitlements file not found at $ENTITLEMENTS_PATH" >&2
  exit 1
fi

rm -rf "$BUILD_ROOT" "$DIST_DIR"
mkdir -p "$STAGING_DIR" "$DIST_DIR"

# ---------------------------------------------------------------------------
# Build (generic macOS destination => universal arm64 + x86_64 binary)
# ---------------------------------------------------------------------------
if [ -n "$DEVELOPER_ID_TEAM" ]; then
  log "Archiving $APP_NAME ($CONFIGURATION, universal)"
  xcodebuild \
    archive \
    -project "$ROOT_DIR/$PROJECT_NAME" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    clean archive

  log "Exporting with Developer ID (team $DEVELOPER_ID_TEAM, automatic signing)"
  cat > "$BUILD_ROOT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$DEVELOPER_ID_TEAM</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>export</string>
</dict></plist>
PLIST
  xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$BUILD_ROOT/ExportOptions.plist" \
    -exportPath "$EXPORT_DIR" \
    -allowProvisioningUpdates
  APP_PATH="$EXPORT_DIR/$APP_NAME.app"
else
  log "Building $APP_NAME ($CONFIGURATION, universal)"
  xcodebuild \
    -project "$ROOT_DIR/$PROJECT_NAME" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    clean build
fi

if [ ! -d "$APP_PATH" ]; then
  echo "error: expected app bundle not found at $APP_PATH" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Signing
# ---------------------------------------------------------------------------
if [ -n "$DEVELOPER_ID_TEAM" ]; then
  log "Signed by Xcode export with Developer ID (cloud-managed certificate)"
  codesign --verify --strict --verbose=2 "$APP_PATH"
elif [ -n "$CODESIGN_IDENTITY" ]; then
  log "Re-signing with: $CODESIGN_IDENTITY"
  codesign \
    --force \
    --options runtime \
    --timestamp \
    --entitlements "$ENTITLEMENTS_PATH" \
    --sign "$CODESIGN_IDENTITY" \
    "$APP_PATH"
  codesign --verify --strict --verbose=2 "$APP_PATH"
else
  log "Keeping the signature produced by xcodebuild (CODESIGN_IDENTITY not set)"
  warn "The app is NOT signed with a Developer ID certificate. The resulting DMG will \
NOT pass Gatekeeper on other Macs until it is signed with a \"Developer ID Application\" \
identity and notarized. To do so, re-run with:
    DEVELOPER_ID_TEAM=<TEAMID> NOTARY_PROFILE=<notarytool-keychain-profile> ./scripts/build-dmg.sh"
fi

# ---------------------------------------------------------------------------
# Package
# ---------------------------------------------------------------------------
log "Creating DMG"
ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

# ---------------------------------------------------------------------------
# Notarization (optional)
# ---------------------------------------------------------------------------
if [ -n "$NOTARY_PROFILE" ]; then
  log "Submitting DMG for notarization (profile: $NOTARY_PROFILE)"
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  log "Stapling notarization ticket"
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
else
  log "Skipping notarization (NOTARY_PROFILE not set)"
  cat <<'EOF'
To enable notarization, store your App Store Connect credentials once:
    xcrun notarytool store-credentials <profile-name> \
      --apple-id <apple-id> --team-id <TEAMID> --password <app-specific-password>
then re-run this script with NOTARY_PROFILE=<profile-name> (and DEVELOPER_ID_TEAM set).
EOF
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
log "Summary"
echo "DMG:        $DMG_PATH"
echo "Size:       $(du -h "$DMG_PATH" | cut -f1)"
echo "Archs:      $(lipo -archs "$APP_PATH/Contents/MacOS/$APP_NAME")"
SIGN_INFO="$(codesign -dvv "$APP_PATH" 2>&1 || true)"
echo "Signature:  $(printf '%s\n' "$SIGN_INFO" | grep -E '^(Authority|Signature)=' | head -1 | cut -d= -f2-)"
echo "Team:       $(printf '%s\n' "$SIGN_INFO" | grep -E '^TeamIdentifier=' | cut -d= -f2-)"
echo "Gatekeeper: (spctl -a -vv; 'rejected' is expected without Developer ID + notarization)"
spctl -a -vv "$APP_PATH" 2>&1 | sed 's/^/            /' || true
