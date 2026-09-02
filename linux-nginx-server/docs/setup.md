# Setup Guide

> **Documented, not executed** — these steps are the exact reproduction path; they were not run against a live server for this deliverable. All commands target **Ubuntu 22.04 or 24.04**.

## Prerequisites

- A fresh VPS or VM running Ubuntu 22.04/24.04, reachable from the internet.
- Root access (cloud providers email you the initial `root` password or let you inject an SSH key at creation).
- This repo present on the server. Get it there with either:

```bash
# Option A: from GitHub (recommended for deployment)
git clone https://github.com/YOUR-USERNAME/YOUR-REPO.git linux-nginx-server

# Option B: scp from your laptop
scp -r linux-nginx-server user@SERVER_IP:/home/user/
```

## Step 1 — Bootstrap a non-root admin user

Log in as root, create your admin user, give it sudo, and copy your SSH key.

```bash
ssh root@SERVER_IP

adduser deployer                      # interactive: set a strong password
usermod -aG sudo deployer             # add to sudo group
mkdir -p /home/deployer/.ssh
cp ~/.ssh/authorized_keys /home/deployer/.ssh/authorized_keys 2>/dev/null || true
chown -R deployer:deployer /home/deployer/.ssh
chmod 700 /home/deployer/.ssh
chmod 600 /home/deployer/.ssh/authorized_keys

# verify sudo works, then stop using root
su - deployer
sudo whoami        # must print: root
```

> The key you copy into `authorized_keys` comes from `~/.ssh/id_ed25519.pub` on your laptop (see Step 2). If you already injected a key at VPS creation, it is already in `authorized_keys`.

## Step 2 — From your laptop: copy your public key (optional)

```bash
# only needed if the server did not get your key at creation time
ssh-keygen -t ed25519 -C "your@email"      # if you have no key yet
ssh-copy-id deployer@SERVER_IP
ssh deployer@SERVER_IP                     # should log in WITHOUT a password
```

## Step 3 — Install the base packages and firewall

Run the real script from this repo (as the sudo user):

```bash
cd ~/linux-nginx-server
sudo bash scripts/install-server.sh
```

What it does:

```bash
sudo apt-get update
sudo apt-get install -y nginx git curl ufw
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable
```

Verify:

```bash
nginx -v              # nginx version
sudo ufw status verbose   # 22, 80, 443 allowed, default deny incoming
```

> ⚠️ **Order matters:** allow `OpenSSH` *before* enabling ufw, or you will lock yourself out. If you ever lock out SSH, reconnect via the provider's web console.

## Step 4 — Run the setup script (one-time)

```bash
sudo bash scripts/setup.sh
```

This script:

1. Creates the `webuser` system user (skipped if it exists).
2. Copies `web/` → `/var/www/hello-web/` and `chown`'s it to `webuser`.
3. Copies `nginx/hello-site.conf` → `/etc/nginx/sites-available/hello-site` and symlinks it into `sites-enabled`.
4. Removes the package default site to avoid a port-80 conflict.
5. Runs `nginx -t` — **fails the whole script** if the config is invalid.
6. Runs `systemctl reload nginx` (zero-downtime).

Expected output ends with:

```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

## Step 5 — (Optional) Enable the demo backend + reverse proxy

```bash
sudo cp systemd/hello-web.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now hello-web
systemctl status hello-web --no-pager      # active (running)

# reverse-proxy server block (forwards /api → 127.0.0.1:3000)
sudo cp nginx/reverse-proxy.conf /etc/nginx/sites-available/reverse-proxy
sudo ln -sf /etc/nginx/sites-available/reverse-proxy /etc/nginx/sites-enabled/reverse-proxy
sudo nginx -t
sudo systemctl reload nginx
```

Test the proxy:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1/api/
# expect 200 (served by the backend on :3000)
```

## Step 6 — Verify the site

```bash
curl -I http://127.0.0.1/                  # expect HTTP/1.1 200 OK
curl -s http://127.0.0.1/ | head -n 5     # HTML content
bash tests/smoke-test.sh                   # PASS: ...
bash scripts/healthcheck.sh                # PASS: http://127.0.0.1/ -> HTTP 200
```

Open `http://SERVER_IP/` in a browser. If nothing loads, the two usual suspects are the firewall and the web root permissions (see `docs/troubleshooting.md`).

## Step 7 — Harden SSH (do this last, after keys work)

Follow `docs/security.md`. The critical three:

```bash
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

> Never close the SSH session before testing a second session with the new settings.

## Files that matter after setup

| Server path | Purpose |
|---|---|
| `/etc/nginx/sites-available/hello-site` | Static site server block |
| `/etc/nginx/sites-enabled/hello-site` | Enabled (symlink) |
| `/var/www/hello-web/` | Web root, owned by `webuser` |
| `/etc/systemd/system/hello-web.service` | Backend unit |
| `/var/log/nginx/access.log`, `error.log` | HTTP logs |

## Idempotency / re-runs

- `install-server.sh` is safe to re-run (`apt install` is idempotent; ufw rules are additive).
- `setup.sh` re-creates the user only if missing and re-copies files — safe to re-run.
- `deploy-site.sh` is the daily deploy path (see `docs/deployment.md`).
