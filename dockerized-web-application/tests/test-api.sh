#!/usr/bin/env bash
# API test suite. Run: bash tests/test-api.sh
# Requires: docker compose up -d, or docker-compose.yml configured.
set -uo pipefail

BASE_URL="${TEST_BASE_URL:-http://localhost}"
FAILURES=0

check() {
  local name="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (got '$got', want '$want')" >&2
    FAILURES=$((FAILURES + 1))
  fi
}

echo "==> Ensuring stack is up"
if ! curl -fsS --max-time 3 "$BASE_URL/health" >/dev/null 2>&1; then
  echo "Stack not reachable — run: docker compose up -d --build" >&2
  exit 1
fi

echo "==> Test /health returns 200"
code=$(curl -fsS --max-time 5 -o /dev/null -w '%{http_code}' "$BASE_URL/health" 2>/dev/null)
check "/health HTTP 200" "$code" "200"

echo "==> Test /health body contains ok"
body=$(curl -fsS --max-time 5 "$BASE_URL/health")
case "$body" in
  *ok*) echo "PASS: /health body contains 'ok' (got: $body)";;
  *)    echo "FAIL: /health body missing 'ok' (got: $body)" >&2; FAILURES=$((FAILURES + 1));;
esac

echo "==> Test / returns 200"
code=$(curl -fsS --max-time 5 -o /dev/null -w '%{http_code}' "$BASE_URL/" 2>/dev/null)
check "/ HTTP 200" "$code" "200"

echo "==> Test /api/message reports DB connected"
msg=$(curl -fsS --max-time 5 "$BASE_URL/api/message")
case "$msg" in
  *'"status":"connected"'*) echo "PASS: /api/message DB status = connected";;
  *) echo "FAIL: /api/message DB not connected (got: $msg)" >&2; FAILURES=$((FAILURES + 1));;
esac

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "ALL TESTS PASSED"
  exit 0
else
  echo "$FAILURES TEST(S) FAILED"
  exit 1
fi
