# /whats-unshipped — what is on main but not on users' devices

When the user runs `/whats-unshipped`, report which commits exist on `main`
but are NOT in the latest shipped build, so "fixed in git" is never confused
with "fixed for users" (this exact confusion hid the APNs notification fix).

## Steps

1. **Find the latest shipped build per platform** from the annotated tags:
   ```bash
   git fetch --tags -q
   git tag -l 'build/ios/*' --sort=-creatordate | head -3
   git tag -l 'build/android/*' --sort=-creatordate | head -3   # after 13 June 2026
   ```
   If no tag exists for a platform, say so and fall back to the most recent
   `chore(release): bump` commit as a best guess — flag it as unverified.

2. **List unshipped commits** for each platform:
   ```bash
   git log --oneline --no-merges <latest-tag>..origin/main
   ```

3. **Classify** each commit by user impact:
   - **User-facing fix/feature** (`fix:`, `feat:` touching lib/, ios/, android/) —
     these are what users are waiting for;
   - **Server-side** (`functions/`, `firestore.rules`) — reaches users at
     deploy time, NOT at build time; check `firebase deploy` status instead
     and say so explicitly;
   - **Internal** (tests, CI, docs, .claude/, .githooks/) — no user impact.

4. **Report**: per platform — latest shipped build + date, count of unshipped
   user-facing changes with a one-line list (lead with fixes for known bugs),
   then a clear recommendation: ship now or wait. If a critical fix (e.g. a
   notification or booking bug) is sitting unshipped for more than a day,
   say so bluntly.
