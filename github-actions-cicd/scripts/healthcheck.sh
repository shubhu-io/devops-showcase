#!/usr/bin/env bash
set -euo pipefail
URL="${1:-http://localhost:3000/health}"
curl -fsS "$URL" | grep -q '"status":"ok"' && echo "HEALTHY $URL" || { echo "UNHEALTHY $URL" >&2; exit 1; }
