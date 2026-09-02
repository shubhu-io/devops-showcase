#!/usr/bin/env bash
# setup.sh - one-time server setup for the hello site.
# 1) create the webuser account, 2) copy web files into the web root,
# 3) install the nginx server block via symlink, 4) nginx -t, 5) reload nginx.
# Run as root or with sudo, from anywhere (uses the repo location to find files).
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: this script must be run as root (use: sudo bash scripts/setup.sh)" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

WEB_USER="webuser"
WEB_ROOT="/var/www/hello-web"
SITE_CONF="$REPO_ROOT/nginx/hello-site.conf"
AVAILABLE="/etc/nginx/sites-available/hello-site"
ENABLED="/etc/nginx/sites-enabled/hello-site"

echo "==> [1/5] Creating web user '$WEB_USER' (skipped if it exists)..."
if ! id "$WEB_USER" >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash "$WEB_USER"
    echo "    created user '$WEB_USER'"
else
    echo "    user '$WEB_USER' already exists"
fi

echo "==> [2/5] Copying web files to $WEB_ROOT ..."
mkdir -p "$WEB_ROOT"
cp -r "$REPO_ROOT/web/." "$WEB_ROOT/"
chown -R "$WEB_USER:$WEB_USER" "$WEB_ROOT"

echo "==> [3/5] Installing nginx server block (symlink into sites-enabled)..."
cp "$SITE_CONF" "$AVAILABLE"
ln -sf "$AVAILABLE" "$ENABLED"
rm -f /etc/nginx/sites-enabled/default

echo "==> [4/5] Testing nginx configuration..."
nginx -t

echo "==> [5/5] Reloading nginx..."
systemctl reload nginx

echo "setup complete - site is live at http://<SERVER_IP>/"
