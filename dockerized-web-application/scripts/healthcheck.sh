#!/usr/bin/env bash
# Health check against the reverse proxy (port 80) or the app directly.
# Used by cron/systemd and by scripts/demo.sh.
set -euo pipefail

BASE_URL="${HEALTHCHECK_URL:-http://localhost/health}"

if ! status=$(curl -fsS --max-time 5 -o /dev/null -w '%{http_code}' "$BASE_URL" 2>/dev/null); then
  echo "HEALTHCHECK FAIL: could not reach $BASE_URL" >&2
  exit 1
fi

if [ "$status" = "200" ]; then
  echo "HEALTHCHECK OK: $BASE_URL returned 200"
  exit 0
else
  echo "HEALTHCHECK FAIL: $BASE_URL returned $status" >&2
  exit 1
fi
