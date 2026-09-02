#!/usr/bin/env bash
# healthcheck.sh
# Purpose: curl retry loop that verifies an HTTP endpoint responds with a
#          2xx status. Usable both from Jenkins (against the EC2 public IP)
#          and on the EC2 host (against 127.0.0.1).
#
# Usage:
#   bash healthcheck.sh http://<EC2_PUBLIC_IP>/health [retries] [sleep]
#   bash healthcheck.sh http://127.0.0.1/health 30 5
set -euo pipefail

URL="${1:?URL required, e.g. http://1.2.3.4/health}"
RETRIES="${2:-20}"
SLEEP="${3:-3}"

log() { echo "[healthcheck] $*"; }

log "Checking ${URL} (up to $((RETRIES * SLEEP))s, one attempt every ${SLEEP}s)"

for i in $(seq 1 "${RETRIES}"); do
  # --fail fails on 4xx/5xx; --retry handles transient network blips.
  if curl --fail --silent --show-error --retry 2 --max-time 5 "${URL}" >/dev/null 2>&1; then
    log "OK: ${URL} responded with HTTP 2xx on attempt ${i}."
    echo "healthy"
    exit 0
  fi
  log "Attempt ${i}/${RETRIES} failed - retrying in ${SLEEP}s..."
  sleep "${SLEEP}"
done

log "FAILED: ${URL} did not return HTTP 2xx after ${RETRIES} attempts."
echo "unhealthy"
exit 1
