#!/usr/bin/env bash
# Build a signed iOS IPA and upload it to TestFlight, fully non-interactively.
#
# Secrets are NOT stored in the repo: this script sources them from a local,
# untracked env file (~/.appstoreconnect/outalma-asc.env). It creates the
# Apple Distribution certificate + App Store provisioning profile via the
# App Store Connect API if they are missing, patches the Runner target's
# signing to Manual *only for the duration of the build* (restored on exit so
# nothing sensitive is committed), then validates and uploads via altool.
#
# Usage:
#   scripts/ios/ship-testflight.sh            # build + validate + upload
#   scripts/ios/ship-testflight.sh --no-upload  # build + validate only
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
ENV_FILE="$HOME/.appstoreconnect/outalma-asc.env"
[ -f "$ENV_FILE" ] || { echo "Missing $ENV_FILE — see scripts/ios/README.md"; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"
export ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH TEAM_ID BUNDLE_ID \
       BUNDLE_RESOURCE_ID PROFILE_NAME DIST_P12 DIST_P12_PASS

PY="${ASC_VENV:-$HOME/.appstoreconnect/asc-venv}/bin/python"
[ -x "$PY" ] || { echo "ASC venv python not found at $PY"; exit 1; }
PBX="ios/Runner.xcodeproj/project.pbxproj"
EXPORT_PLIST="$(mktemp -t outalma-export).plist"

cleanup() {
  # Always restore the untouched project file so signing config is never committed.
  [ -f "$PBX.shipbak" ] && mv -f "$PBX.shipbak" "$PBX" && echo "[restore] project.pbxproj restored."
  rm -f "$EXPORT_PLIST"
}
trap cleanup EXIT

echo "==> 1/5 Ensure signing assets (cert + profile)"
"$PY" scripts/ios/asc_assets.py ensure

echo "==> 2/5 Patch Runner signing to Manual (temporary)"
cp "$PBX" "$PBX.shipbak"
"$PY" scripts/ios/patch_signing.py "$PBX" "$DIST_CERT_NAME" "$PROFILE_NAME"

cat > "$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store</string>
  <key>teamID</key><string>${TEAM_ID}</string>
  <key>uploadSymbols</key><true/>
  <key>compileBitcode</key><false/>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Apple Distribution</string>
  <key>provisioningProfiles</key><dict>
    <key>${BUNDLE_ID}</key><string>${PROFILE_NAME}</string>
  </dict>
  <key>stripSwiftSymbols</key><true/>
  <key>destination</key><string>export</string>
</dict></plist>
PLIST

echo "==> 3/5 flutter build ipa"
flutter build ipa --release --export-options-plist="$EXPORT_PLIST"

IPA="$(ls -t build/ios/ipa/*.ipa | head -1)"
[ -n "$IPA" ] || { echo "No IPA produced"; exit 1; }
echo "    built: $IPA"

echo "==> 4/5 Validate with App Store Connect"
xcrun altool --validate-app --type ios -f "$IPA" \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

if [ "${1:-}" = "--no-upload" ]; then
  echo "==> 5/5 skipped (--no-upload). IPA ready: $IPA"
  exit 0
fi

echo "==> 5/5 Upload to TestFlight"
xcrun altool --upload-app --type ios -f "$IPA" \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
echo "[done] uploaded. App Store Connect will process the build (5-15 min)."
