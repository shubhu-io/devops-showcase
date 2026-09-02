#!/usr/bin/env bash
# healthcheck.sh - simple HTTP health check with exit-code handling.
# Usage: bash scripts/healthcheck.sh [URL] [EXPECTED_CODE] [TIMEOUT]
#   defaults: URL=http://127.0.0.1/  EXPECTED_CODE=200  TIMEOUT=10
# Exit 0 on success, 1 on any failure. Safe for cron / CI.
set -euo pipefail

URL="${1:-http://127.0.0.1/}"
EXPECTED_CODE="${2:-200}"
TIMEOUT="${3:-10}"

if ! command -v curl >/dev/null 2>&1; then
    echo "FAIL: curl is not installed (sudo apt install -y curl)" >&2
    exit 1
fi

code="$(curl -fsS -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT" "$URL" 2>/dev/null)" || {
    echo "FAIL: could not reach $URL (curl exit code $?)" >&2
    exit 1
}

if [[ "$code" != "$EXPECTED_CODE" ]]; then
    echo "FAIL: expected HTTP $EXPECTED_CODE from $URL but got $code" >&2
    exit 1
fi

echo "PASS: $URL -> HTTP $code"
