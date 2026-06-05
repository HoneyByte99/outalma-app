#!/usr/bin/env python3
"""Ensure an Apple Distribution certificate + App Store provisioning profile
exist and are installed locally, using the App Store Connect API.

No secrets live in this file. All credentials are read from environment
variables (exported by scripts/ios/ship-testflight.sh from a local, untracked
env file at ~/.appstoreconnect/outalma-asc.env).

Required env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH, TEAM_ID,
BUNDLE_RESOURCE_ID, PROFILE_NAME, DIST_P12, DIST_P12_PASS.

Usage: asc_assets.py ensure   # creates cert+profile if missing, installs both
"""
import base64
import json
import os
import subprocess
import sys
import time

import jwt
import requests

BASE = "https://api.appstoreconnect.apple.com"


def env(name):
    v = os.environ.get(name)
    if not v:
        sys.exit(f"Missing required env var: {name}")
    return v


def token():
    with open(env("ASC_KEY_PATH")) as f:
        key = f.read()
    now = int(time.time())
    payload = {
        "iss": env("ASC_ISSUER_ID"),
        "iat": now,
        "exp": now + 1200,
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(
        payload, key, algorithm="ES256",
        headers={"kid": env("ASC_KEY_ID"), "typ": "JWT"},
    )


def api(method, path, body=None, params=None):
    h = {"Authorization": f"Bearer {token()}", "Content-Type": "application/json"}
    r = requests.request(method, BASE + path, headers=h,
                         data=json.dumps(body) if body else None, params=params)
    return r.status_code, (r.json() if r.text else {})


def keychain_has_distribution():
    out = subprocess.run(
        ["security", "find-identity", "-v", "-p", "codesigning"],
        capture_output=True, text=True).stdout
    return "Apple Distribution" in out


def ensure_certificate():
    """Return an ASC certificate id for a DISTRIBUTION cert whose private key is
    in the keychain. Creates a new cert (generating the key locally) if the
    keychain has no distribution identity."""
    if keychain_has_distribution():
        print("[cert] Apple Distribution identity already in keychain.")
        # Find a matching ASC cert id (best-effort, for the profile relationship).
        sc, data = api("GET", "/v1/certificates", params={"limit": 200})
        for c in data.get("data", []):
            if c["attributes"].get("certificateType") == "DISTRIBUTION":
                return c["id"]
        sys.exit("[cert] Keychain has a distribution identity but ASC lists none "
                 "of type DISTRIBUTION — resolve manually.")

    print("[cert] No distribution identity in keychain — creating one via ASC API.")
    work = os.path.expanduser("~/.appstoreconnect/outalma-dist")
    os.makedirs(work, exist_ok=True)
    key_pem = os.path.join(work, "dist_key.pem")
    csr = os.path.join(work, "dist.csr")
    subprocess.run(["openssl", "genrsa", "-out", key_pem, "2048"], check=True)
    subprocess.run(["openssl", "req", "-new", "-key", key_pem, "-out", csr,
                    "-subj", "/CN=Outalma Distribution/O=Outalma/C=FR"], check=True)
    body = {"data": {"type": "certificates", "attributes": {
        "certificateType": "DISTRIBUTION", "csrContent": open(csr).read()}}}
    sc, data = api("POST", "/v1/certificates", body)
    if sc not in (200, 201):
        sys.exit(f"[cert] creation failed ({sc}): {json.dumps(data)[:800]}")
    cert_id = data["data"]["id"]
    der = base64.b64decode(data["data"]["attributes"]["certificateContent"])
    cert_der = os.path.join(work, "dist_cert.der")
    cert_pem = os.path.join(work, "dist_cert.pem")
    open(cert_der, "wb").write(der)
    subprocess.run(["openssl", "x509", "-inform", "DER", "-in", cert_der,
                    "-out", cert_pem], check=True)
    p12 = env("DIST_P12")
    pw = env("DIST_P12_PASS")
    subprocess.run(["openssl", "pkcs12", "-export", "-out", p12, "-inkey", key_pem,
                    "-in", cert_pem, "-passout", f"pass:{pw}", "-legacy"], check=True)
    subprocess.run(["security", "import", p12, "-k",
                    os.path.expanduser("~/Library/Keychains/login.keychain-db"),
                    "-P", pw, "-T", "/usr/bin/codesign", "-T",
                    "/usr/bin/productbuild", "-A"], check=True)
    print(f"[cert] created and imported (id={cert_id}).")
    return cert_id


def ensure_profile(cert_id):
    name = env("PROFILE_NAME")
    sc, data = api("GET", "/v1/profiles",
                   params={"filter[name]": name, "limit": 1})
    prof = data.get("data", [None])[0] if data.get("data") else None
    if not prof:
        print(f"[profile] '{name}' not found — creating App Store profile.")
        body = {"data": {
            "type": "profiles",
            "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds",
                                      "id": env("BUNDLE_RESOURCE_ID")}},
                "certificates": {"data": [{"type": "certificates", "id": cert_id}]},
            }}}
        sc, data = api("POST", "/v1/profiles", body)
        if sc not in (200, 201):
            sys.exit(f"[profile] creation failed ({sc}): {json.dumps(data)[:800]}")
        prof = data["data"]
    a = prof["attributes"]
    dest_dir = os.path.expanduser("~/Library/MobileDevice/Provisioning Profiles")
    os.makedirs(dest_dir, exist_ok=True)
    dest = os.path.join(dest_dir, f"{a['uuid']}.mobileprovision")
    open(dest, "wb").write(base64.b64decode(a["profileContent"]))
    print(f"[profile] installed '{a['name']}' uuid={a['uuid']}")


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] != "ensure":
        sys.exit("usage: asc_assets.py ensure")
    cid = ensure_certificate()
    ensure_profile(cid)
    print("[ok] signing assets ready.")
