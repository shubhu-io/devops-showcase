#!/usr/bin/env bash
# ec2-bootstrap.sh
# Purpose: EC2 user-data bootstrap script for Ubuntu 22.04 / 24.04.
#          Installs Docker Engine, enables it on boot, opens the required
#          ports, pulls the nginx image used as a reverse proxy, and prints
#          a DONE marker so the deployment script can wait for bootstrap.
#
# Usage: paste the contents of this file into the "User data" field when
#        launching an EC2 instance, OR upload it and run:
#          sudo bash /home/ubuntu/ec2-bootstrap.sh
#
# NOTE on ports: the EC2 security group is the real firewall that should
# allow 22 (your IP only) and 80 (0.0.0.0/0). ufw rules below are defense
# in depth on the host itself.
set -euo pipefail

log() { echo "[bootstrap] $*"; }

log "Starting EC2 user-data bootstrap on $(lsb_release -ds 2>/dev/null || echo 'Ubuntu')"

# --- 1. Update system packages ---------------------------------------------
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# --- 2. Install prerequisites for Docker's apt repo -------------------------
apt-get install -y ca-certificates curl gnupg

# --- 3. Add the official Docker apt repository ------------------------------
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# shellcheck disable=SC1091
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

# --- 4. Install Docker Engine -----------------------------------------------
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# --- 5. Enable Docker and add ubuntu user to the docker group ----------------
systemctl enable --now docker
usermod -aG docker ubuntu

# --- 6. Host firewall (defense in depth; security group is primary) ----------
# Install ufw if missing, then allow ssh and http(s). Do NOT enable ufw until
# you have verified the security group already allows your SSH IP, otherwise
# you can lock yourself out.
apt-get install -y ufw || true
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
log "NOTE: ufw rules staged but NOT enabled automatically to avoid lockout."

# --- 7. Pull the nginx image used by the reverse proxy -----------------------
docker pull nginx:1.27-alpine

# --- 8. Pre-pull the app image so first deploy is fast ------------------------
# The image comes from the Jenkins host; if a registry is used the deploy
# script will pull from there instead. This is a no-op when nothing is tagged.
docker pull node-app:latest || true

# --- 9. Ready marker ----------------------------------------------------------
mkdir -p /opt/devops
touch /opt/devops/bootstrap-done
log "Bootstrap complete. Marker written to /opt/devops/bootstrap-done"
log "DONE"
