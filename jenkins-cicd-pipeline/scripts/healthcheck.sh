#!/usr/bin/env bash
# ============================================================================
# Health-check helper for the hello-app container / pipeline.
#
#   bash scripts/healthcheck.sh                 # checks default URL
#   bash scripts/healthcheck.sh http://localhost:8091/health
# ============================================================================
set -euo pipefail

URL="${1:-http://localhost:8090/health}"

echo "Checking health endpoint: $URL"

if command -v curl >/dev/null 2>&1; then
  BODY="$(curl -sf --max-time 5 "$URL")" || { echo "FAIL: no response from $URL"; exit 1; }
elif command -v wget >/dev/null 2>&1; then
  BODY="$(wget -qO- --timeout=5 "$URL")" || { echo "FAIL: no response from $URL"; exit 1; }
else
  echo "FAIL: neither curl nor wget is installed."
  exit 1
fi

echo "Response: $BODY"

if printf '%s' "$BODY" | grep -q '"status":"ok"'; then
  echo "HEALTHY"
else
  echo "UNHEALTHY: expected {\"status\":\"ok\"}"
  exit 1
fi
