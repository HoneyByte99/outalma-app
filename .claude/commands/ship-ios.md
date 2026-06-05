When the user runs `/ship-ios`, build a signed iOS IPA and ship it to TestFlight
**non-interactively**. No Apple credentials live in the repo — they are read
from a local, untracked env file.

## Prerequisites (one-time, local machine only)

A local env file at `~/.appstoreconnect/outalma-asc.env` must exist (see
`scripts/ios/README.md` for the exact keys). It holds the App Store Connect API
key id/issuer, team id, bundle id, distribution cert name, profile name, and the
`.p12` location/passphrase. **Never commit it.** A Python venv with
`pyjwt cryptography requests` must exist at `~/.appstoreconnect/asc-venv`.

## Steps

1. Confirm the build number: read `version:` in `pubspec.yaml`. The build number
   (the `+N` suffix) MUST be strictly greater than the latest build on App Store
   Connect. Bump it and commit (`chore(release): bump version to 1.0.0+N`) before
   building if needed.
2. Run the pipeline:
   ```bash
   scripts/ios/ship-testflight.sh            # build + validate + upload
   scripts/ios/ship-testflight.sh --no-upload  # build + validate only
   ```
   The script (see `scripts/ios/`):
   - creates the Apple Distribution cert + App Store provisioning profile via the
     ASC API if they are missing, and installs them;
   - temporarily patches the Runner target to Manual signing, **restoring
     `project.pbxproj` on exit** (a trap) so signing config is never committed;
   - runs `flutter build ipa`, validates, and uploads via `xcrun altool`.
3. Long steps (archive, upload) should be run with `run_in_background: true`;
   wait for the completion notification, then check the log tail.
4. After a successful upload, tell the user: App Store Connect needs ~5–15 min to
   process the build; they may be asked for export-compliance (encryption) in the
   ASC UI unless `ITSAppUsesNonExemptEncryption` is set in `ios/Runner/Info.plist`.

## Guardrails

- Do NOT commit `project.pbxproj` signing changes, the `.p12`, the `.env`, or any
  key material. Only the scripts under `scripts/ios/` (which contain no secrets)
  are committed.
- If `security find-identity -v -p codesigning` already lists an
  "Apple Distribution" identity, the script reuses it instead of creating a new one.
