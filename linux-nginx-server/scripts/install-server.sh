#!/usr/bin/env bash
# install-server.sh - bootstrap a fresh Ubuntu 22.04/24.04 server.
# Installs nginx, git, curl, ufw and configures the firewall.
# Run as root or with sudo.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: this script must be run as root (use: sudo bash scripts/install-server.sh)" >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "==> [1/4] Updating apt package lists..."
apt-get update

echo "==> [2/4] Installing nginx, git, curl, ufw..."
apt-get install -y nginx git curl ufw

echo "==> [3/4] Configuring ufw firewall..."
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

echo "==> [4/4] Done. Versions and firewall state:"
nginx -v
ufw status verbose
