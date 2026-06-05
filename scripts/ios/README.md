# iOS release automation (TestFlight)

Builds a signed IPA and uploads it to TestFlight non-interactively, creating the
signing certificate + provisioning profile via the App Store Connect API when
missing. **No secrets are stored in this repo.**

## Files

- `ship-testflight.sh` — orchestrator (`/ship-ios` runs this).
- `asc_assets.py` — ensures the Apple Distribution cert + App Store profile exist
  and are installed (reads credentials from env, no secrets in the file).
- `patch_signing.py` — temporarily sets the Runner target to Manual signing;
  the orchestrator restores `project.pbxproj` on exit.

## One-time local setup (never committed)

1. App Store Connect API key (`.p8`) at
   `~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8`.
2. Python venv:
   ```bash
   python3 -m venv ~/.appstoreconnect/asc-venv
   ~/.appstoreconnect/asc-venv/bin/pip install pyjwt cryptography requests
   ```
3. Local env file `~/.appstoreconnect/outalma-asc.env` (chmod 600) with:
   ```sh
   ASC_KEY_ID="..."              # App Store Connect API Key ID
   ASC_ISSUER_ID="..."           # ASC API Issuer ID (UUID)
   ASC_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8"
   TEAM_ID="..."                 # Apple Developer team id
   BUNDLE_ID="com.honeybyte.outalmaApp"
   BUNDLE_RESOURCE_ID="..."      # ASC bundleIds resource id
   DIST_CERT_NAME="Apple Distribution: <Name> (<TEAM_ID>)"
   PROFILE_NAME="Outalma App Store"
   DIST_P12="$HOME/.appstoreconnect/outalma-dist/dist.p12"
   DIST_P12_PASS="..."
   ASC_VENV="$HOME/.appstoreconnect/asc-venv"
   ```

If `asc_assets.py` creates a new distribution certificate, it writes the private
key and `.p12` under `~/.appstoreconnect/outalma-dist/` (outside the repo). Keep
that directory backed up — losing it means re-issuing the certificate.

## Run

```bash
scripts/ios/ship-testflight.sh             # build + validate + upload
scripts/ios/ship-testflight.sh --no-upload # build + validate only
```
