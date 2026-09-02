# Security

> **Documented, not executed** — this hardening guide is for an Ubuntu 22.04/24.04 server and was not applied to a live machine for this deliverable. No secrets appear anywhere in this repository.

## Threat model

A public VPS is scanned by bots within minutes of creation. The realistic attacks:

| Threat | Defense in this project |
|---|---|
| Password guessing / brute force over SSH | Key-only auth, password auth disabled, non-root admin user |
| Root compromise via admin account | `PermitRootLogin no`, sudo-only escalation |
| Unnecessary open ports probed | ufw default-deny incoming, only 22/80/443 allowed |
| Web application exploitation | No dynamic code exposed on :80; backend bound to loopback only |
| Secret leakage | No secrets in repo; `.env`, `*.pem`, `*.key` gitignored |
| Unpatched software | `apt update && apt upgrade` as a maintenance habit |

## 1. Non-root operator user (least privilege)

Never do day-to-day work as `root`.

```bash
sudo adduser deployer
sudo usermod -aG sudo deployer
```

Then log in as `deployer` and use `sudo` only for privileged steps. The web server itself runs as `webuser`, not root:

```bash
sudo useradd -m -s /bin/bash webuser     # done by scripts/setup.sh if missing
sudo chown -R webuser:webuser /var/www/hello-web
```

## 2. SSH hardening

Keys first. On your laptop:

```bash
ssh-keygen -t ed25519 -C "your@email"     # creates ~/.ssh/id_ed25519(.pub)
ssh-copy-id deployer@SERVER_IP            # installs the public key on the server
```

Verify key login works, *then* harden `/etc/ssh/sshd_config`:

```conf
Port 22
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication no
MaxAuthTries 4
AllowUsers deployer
```

Apply and test **carefully** (never close the existing session before testing a new one):

```bash
sudo systemctl restart ssh
# NEW terminal:
ssh deployer@SERVER_IP
# only if the new session works, close the old one
```

> If you ever lock yourself out, use the provider's out-of-band console (web VNC/console) — keep that path documented.

Optional extra layer: `fail2ban` to jail repeated failed attempts:

```bash
sudo apt install -y fail2ban
```

## 3. Firewall — ufw

Applied by `scripts/install-server.sh`:

```bash
sudo ufw allow OpenSSH        # 22/tcp — keep this rule FIRST
sudo ufw allow 'Nginx Full'   # 80/tcp + 443/tcp
sudo ufw --force enable
```

Verify:

```bash
sudo ufw status verbose
# Default: deny (incoming)
# 22/tcp (OpenSSH)      ALLOW IN  Anywhere
# 80,443 (Nginx Full)   ALLOW IN  Anywhere
```

Ports NOT opened: `3000` (backend). The backend binds to `127.0.0.1` precisely so ufw does not need a rule for it — Nginx reaches it over loopback, the internet cannot.

## 4. File and directory permissions

```bash
# Web root readable by nginx worker (webuser), not writable by "others"
sudo chown -R webuser:webuser /var/www/hello-web
sudo chmod -R u=rwX,g=rX,o=rX /var/www/hello-web

# Scripts executable by owner, readable by group
chmod 755 scripts/*.sh tests/smoke-test.sh

# SSH keys stay private
chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
```

`644` files (owner rw, others r) are correct for web content; `755` for scripts; `600/700` for anything containing secrets.

## 5. No secrets in the repository

- `.gitignore` excludes `*.log`, `.env`, `.env.*`, `*.pem`, `*.key`, and temp files.
- Configs in this repo contain **no passwords, tokens, or keys** — only safe defaults.
- If a service ever needs a credential, use a systemd `EnvironmentFile=/etc/hello-web/secrets.env` that lives outside git, owned by root with `0600`:
  ```bash
  sudo install -o root -g root -m 0600 /dev/null /etc/hello-web/secrets.env
  ```

## 6. Least privilege recap

| Component | Runs as | Needs |
|---|---|---|
| nginx workers | `www-data` (default) | read web root |
| hello-web.service | `webuser` | read `/var/www/hello-web`, bind 127.0.0.1:3000 |
| deploy scripts | `sudo` (human-initiated) | write web root + reload nginx |
| admin user | `deployer` + sudo group | operational control |

No service ever runs as root; the deploy scripts require `sudo` only because copying into `/var/www` and reloading nginx are privileged.

## 7. Maintenance routine

```bash
sudo apt update && sudo apt upgrade   # patch weekly-ish
sudo unattended-upgrades              # optional: auto security patches
tail -f /var/log/nginx/access.log     # watch for odd traffic
sudo journalctl -u ssh --since today  # check SSH logins
```

## Checklist

- [ ] `deployer` user exists with sudo; root SSH login disabled
- [ ] Key auth works; `PasswordAuthentication no`
- [ ] ufw active with only OpenSSH + Nginx Full allowed
- [ ] Backend listens on 127.0.0.1:3000 only (`ss -ltnp | grep 3000`)
- [ ] Web root owned by `webuser`, no world-writable files
- [ ] No secrets in the repo; `.gitignore` rules present
- [ ] `apt` up to date
