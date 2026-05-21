#!/usr/bin/env bash
# Local dev launcher — injects MAPS_API_KEY into the Dart layer.
#
# Usage:
#   MAPS_API_KEY=AIza... ./scripts/run.sh                    # default device
#   MAPS_API_KEY=AIza... ./scripts/run.sh -d chrome          # web
#   MAPS_API_KEY=AIza... ./scripts/run.sh --release          # any extra flags
#
# The same key must also live in ios/Flutter/Secrets.xcconfig (iOS) and
# android/local.properties (Android) for native SDK rendering.

set -euo pipefail

if [[ -z "${MAPS_API_KEY:-}" ]]; then
  echo "❌ MAPS_API_KEY is not set." >&2
  echo "   export MAPS_API_KEY=AIza... and retry, or run:" >&2
  echo "   MAPS_API_KEY=AIza... ./scripts/run.sh" >&2
  exit 1
fi

exec flutter run --dart-define=MAPS_API_KEY="$MAPS_API_KEY" "$@"
