#!/usr/bin/env python3
"""Light ASC pre-check: verify the agreement wall is gone and list latest builds.

Reads credentials from env (same as asc_assets.py). Prints:
- app query result (or FORBIDDEN.REQUIRED_AGREEMENTS_MISSING_OR_EXPIRED if still walled)
- the highest existing TestFlight build number for the bundle
"""
import json
import os
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


def api(method, path, params=None):
    h = {"Authorization": f"Bearer {token()}", "Content-Type": "application/json"}
    r = requests.request(method, BASE + path, headers=h, params=params)
    return r.status_code, (r.json() if r.text else {})


def main():
    bundle = env("BUNDLE_ID")
    # 1. Find the app resource by bundle id.
    sc, data = api("GET", "/v1/apps", params={"filter[bundleId]": bundle, "limit": 1})
    print(f"[apps] status={sc}")
    if sc == 403:
        blob = json.dumps(data)
        print(blob[:1200])
        if "REQUIRED_AGREEMENTS" in blob:
            print("VERDICT: WALLED")
            sys.exit(2)
        print("VERDICT: FORBIDDEN_OTHER")
        sys.exit(3)
    if sc != 200:
        print(json.dumps(data)[:1200])
        print("VERDICT: ERROR")
        sys.exit(4)
    apps = data.get("data", [])
    if not apps:
        print("VERDICT: NO_APP_FOUND")
        sys.exit(5)
    app = apps[0]
    app_id = app["id"]
    print(f"[apps] found app id={app_id} name={app['attributes'].get('name')}")

    # 2. List builds, find highest version (build number).
    sc, data = api("GET", "/v1/builds",
                   params={"filter[app]": app_id,
                           "sort": "-version", "limit": 20})
    print(f"[builds] status={sc}")
    builds = data.get("data", [])
    nums = []
    for b in builds:
        v = b["attributes"].get("version")
        state = b["attributes"].get("processingState")
        print(f"  build version={v} state={state}")
        try:
            nums.append(int(v))
        except (TypeError, ValueError):
            pass
    top = max(nums) if nums else 0
    print(f"LATEST_BUILD_NUMBER={top}")
    print("VERDICT: CLEAR")


if __name__ == "__main__":
    main()
