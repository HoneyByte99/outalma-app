#!/usr/bin/env python3
"""Insert manual code-signing settings into the Runner target's Release build
config in ios/Runner.xcodeproj/project.pbxproj, scoped to Runner ONLY (passing
these as global xcodebuild settings breaks CocoaPods targets).

Idempotent. The caller is responsible for backing up / restoring the file
(ship-testflight.sh keeps a .bak and restores it on exit) so nothing sensitive
is ever committed.

Usage: patch_signing.py <pbxproj> "<identity>" "<profile name>"
"""
import re
import sys

pbx, identity, profile = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(pbx).read()
if "PROVISIONING_PROFILE_SPECIFIER" in src and profile in src:
    print("[patch] already patched.")
    sys.exit(0)

lines = src.split("\n")
out = []
in_release = False
brace = 0
patched = 0
for i, ln in enumerate(lines):
    out.append(ln)
    # Enter a "Release" XCBuildConfiguration block.
    if re.search(r"/\* Release \*/ = \{", ln):
        in_release = True
        brace = 0
    if in_release:
        brace += ln.count("{") - ln.count("}")
        # Insert right after the Runner target's entitlements line (only the
        # Runner config has CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements).
        if "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;" in ln:
            indent = ln[: len(ln) - len(ln.lstrip())]
            out.append(f'{indent}CODE_SIGN_STYLE = Manual;')
            out.append(f'{indent}"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "{identity}";')
            out.append(f'{indent}PROVISIONING_PROFILE_SPECIFIER = "{profile}";')
            patched += 1
        if brace <= 0:
            in_release = False

if patched == 0:
    sys.exit("[patch] could not find Runner Release config to patch.")
open(pbx, "w").write("\n".join(out))
print(f"[patch] manual signing applied to {patched} Release config(s).")
