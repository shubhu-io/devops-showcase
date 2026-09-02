#!/usr/bin/env bash
# deploy-site.sh - deploy the latest commit to the web root.
# 1) git pull (fast-forward only), 2) copy web/ into /var/www/hello-web,
# 3) fix ownership. Run as root or with sudo.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: this script must be run as root (use: sudo bash scripts/deploy-site.sh)" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

WEB_USER="webuser"
WEB_ROOT="/var/www/hello-web"

echo "==> [1/3] Pulling latest changes (fast-forward only)..."
if [[ ! -d "$REPO_ROOT/.git" ]]; then
    echo "ERROR: '$REPO_ROOT' is not a git repository. Clone it first:" >&2
    echo "    git clone <repository-url> '$REPO_ROOT'" >&2
    exit 1
fi
git -C "$REPO_ROOT" pull --ff-only

echo "==> [2/3] Copying web files to $WEB_ROOT ..."
mkdir -p "$WEB_ROOT"
cp -r "$REPO_ROOT/web/." "$WEB_ROOT/"

echo "==> [3/3] Fixing ownership ..."
chown -R "$WEB_USER:$WEB_USER" "$WEB_ROOT"

echo "deploy complete. Verify with: bash tests/smoke-test.sh"
