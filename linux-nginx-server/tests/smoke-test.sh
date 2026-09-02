#!/usr/bin/env bash
# smoke-test.sh - verify nginx is running and serving the hello page with HTTP 200.
# Prints PASS/FAIL and exits non-zero on failure (CI/cron friendly).
set -euo pipefail

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

command -v curl >/dev/null 2>&1 || fail "curl is not installed (sudo apt install -y curl)"
command -v systemctl >/dev/null 2>&1 || fail "systemctl is not available - are you on systemd?"

if ! systemctl is-active --quiet nginx 2>/dev/null; then
    fail "nginx is not running. Start it with: sudo systemctl start nginx"
fi
echo "==> nginx is active. Testing http://127.0.0.1/ ..."

http_code="$(curl -fsS -o /dev/null -w '%{http_code}' --max-time 10 http://127.0.0.1/ 2>/dev/null)" || true
if [[ "$http_code" != "200" ]]; then
    fail "expected HTTP 200 from http://127.0.0.1/, got '${http_code:-connection failure}'"
fi

body="$(curl -fsS --max-time 10 http://127.0.0.1/ 2>/dev/null)" || true
if ! grep -qi 'hello' <<<"$body"; then
    fail "page body does not contain expected 'Hello' content"
fi

echo "PASS: nginx is active and http://127.0.0.1/ returned 200 with expected content"
