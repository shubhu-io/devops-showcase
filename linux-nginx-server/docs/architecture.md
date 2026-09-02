# Architecture

> **Documented, not executed** — this describes the intended design; no live server was provisioned for this deliverable.

## 1. What we are building

A single Ubuntu server that:

1. accepts SSH on port 22 for administration,
2. serves a static **hello** site on port 80 via Nginx,
3. optionally reverse-proxies `/api` to a backend on `127.0.0.1:3000`,
4. supervises that backend with systemd (`Restart=on-failure`),
5. blocks everything except ports 22/80/443 with ufw,
6. receives updates through `git pull` + copy-to-webroot.

### Data flow

```
Browser ──HTTP :80──▶ Nginx ──▶ /var/www/hello-web/index.html   (static)
                         └──▶ /api ──proxy_pass──▶ 127.0.0.1:3000  (backend)

Admin ──SSH :22──▶ Ubuntu ──systemctl──▶ nginx / hello-web
                       └──ufw: allow OpenSSH, Nginx Full──▶ everything else dropped
```

## 2. Layer-by-layer breakdown

### 2.1 Client layer
- **Developer:** edits code, commits, pushes to GitHub.
- **Browser:** requests `http://server/`; Nginx answers in milliseconds because no application framework is involved.

### 2.2 Source control layer — GitHub
- Holds the single source of truth for the repo (including these docs, configs, and scripts).
- Enables **rollback**: `git checkout <previous-tag>` is a valid rollback mechanism.
- Enables **audit**: every change to the site is a commit with a message.

### 2.3 Server OS layer — Linux
- Ubuntu 22.04/24.04 provides the filesystem (`/etc`, `/var`, `/usr`, `/home`), the user/group/permission model, and process management.
- Nginx, git, curl, ufw, systemd all run as processes governed by this layer.
- Multi-user isolation: `root`, the admin sudo user, and a dedicated `webuser` each have scoped powers.

### 2.4 Firewall layer — ufw
- Default policy: **deny incoming**.
- Rules: `allow OpenSSH` (22), `allow 'Nginx Full'` (80 + 443).
- Result: from the internet, only SSH and HTTP(S) are reachable; everything else is dropped.

### 2.5 Web server layer — Nginx
- **Static site:** `listen 80 default_server; root /var/www/hello-web; index index.html;` plus `location /` with `try_files $uri $uri/ =404;`.
- **Reverse proxy:** a second server block maps `location /api/` to `proxy_pass http://127.0.0.1:3000` and forwards `Host`, `X-Real-IP`, `X-Forwarded-For`, and `X-Forwarded-Proto`.
- Nginx also writes `access.log` and `error.log` for observability.

### 2.6 Application layer — hello-web service
- A tiny demo process listening only on `127.0.0.1:3000` (never exposed to the internet — ufw does not allow 3000).
- Managed by the systemd unit `systemd/hello-web.service`:
  - `After=network.target` — start after the network is up.
  - `User=webuser` / `Group=webuser` — least privilege.
  - `Restart=on-failure` + `RestartSec=3` — crash recovery.
  - `WantedBy=multi-user.target` — starts at boot.

### 2.7 Observability layer — logs
- `journalctl -u nginx`, `journalctl -u hello-web`, and the files under `/var/log/nginx/` are the primary diagnostic sources.

## 3. Technology deep-dives

### 3.1 Linux

- **What is it?** An open-source operating system family. Ubuntu is a Linux distribution with predictable packaging (`apt`) and a 5-year LTS support window.
- **Why do we need it?** Every layer above (Nginx, systemd, SSH, ufw, Bash) runs on it; it is the substrate of the whole project.
- **What problem does it solve?** It gives us a stable, multi-user, network-ready environment with a proven permission model and package ecosystem.
- **What happens without it?** There is no place to install Nginx, no users/groups/permissions, no systemd; the deployment simply cannot exist.
- **Why was it selected?** Ubuntu LTS is the most common choice for small VPS deployments, is well documented, and has excellent community support.
- **Alternative technologies:** other Linux distros (Debian, Rocky/Alma, openSUSE), or BSD (FreeBSD); Windows Server.
- **When should we use the alternative?** When the org standardizes on RHEL-based distros (commercial support, SELinux), or on Windows for specific .NET/legacy workloads.

### 3.2 Nginx

- **What is it?** A high-performance HTTP server and reverse proxy.
- **Why do we need it?** Someone must accept HTTP requests on port 80 and return the HTML. Nginx does this with tiny memory footprint and excellent concurrency.
- **What problem does it solve?** It serves static files directly (fast) and forwards dynamic `/api` traffic to a backend (reverse proxy), hiding the backend from the internet.
- **What happens without it?** Browsers would hit a closed port; there would be no HTTP layer, no `location` routing, no logs, no `proxy_pass`.
- **Why was it selected?** Event-driven model (handles thousands of connections with few threads), simple config, mature reverse-proxy features.
- **Alternative technologies:** Apache httpd, Caddy, HAProxy (proxy-only), or app-server-embedded HTTP (Node/Express, Python/Gunicorn).
- **When should we use the alternative?** Apache when .htaccess ecosystem compatibility matters; Caddy when you want automatic HTTPS with minimal config; Gunicorn directly when there is no need for a separate web tier.

### 3.3 SSH

- **What is it?** Secure Shell: an encrypted protocol for remote login and command execution.
- **Why do we need it?** The server is headless; every admin action happens over SSH.
- **What problem does it solve?** Encrypts the session, authenticates the user with a key pair instead of a guessable password, and enables `scp`/`git`/`rsync` over the same channel.
- **What happens without it?** You would need console access physically or via a cloud web console for every change — slow, error-prone, and not scriptable.
- **Why was it selected?** It is the de-facto standard for remote Linux admin; every cloud provider and VPS supports it natively.
- **Alternative technologies:** telnet (unencrypted — never on the public internet), vendor web consoles (console-only), VPN + RDP (Windows-centric).
- **When should we use the alternative?** A VPN (WireGuard/OpenVPN) is appropriate as an extra layer for private networks; otherwise SSH with hardened settings is the right default.

### 3.4 systemd

- **What is it?** The init system (PID 1) on modern Ubuntu; it boots the OS, starts services, and supervises them.
- **Why do we need it?** The demo backend must start at boot and restart if it crashes; doing that with cron or a manual script is fragile.
- **What problem does it solve?** Declarative units (`hello-web.service`), dependency ordering (`After=`), crash recovery (`Restart=on-failure`, `RestartSec`), and centralized logging (`journalctl`).
- **What happens without it?** A crashed backend stays down until a human notices; nothing restarts it and there is no dependency management.
- **Why was it selected?** It is the default on Ubuntu, so no extra install, and its feature set matches the need exactly.
- **Alternative technologies:** SysV init scripts, Upstart (older Ubuntu), runit, supervisord.
- **When should we use the alternative?** In minimal containers or distros that prefer runit; supervisord when supervising processes inside an environment without systemd (e.g., some Docker images).

### 3.5 Git

- **What is it?** A distributed version control system.
- **Why do we need it?** Code + configs must have history, be shareable, and be deployable in a repeatable way.
- **What problem does it solve?** Every change is a commit (audit), `git push` transports code to GitHub, `git pull` delivers it to the server, and `git checkout <tag>` rolls it back.
- **What happens without it?** Manual copy-paste of files to the server, no history, no rollback, no collaboration, no audit trail.
- **Why was it selected?** GitHub is ubiquitous, git handles both docs and configs well, and the pull-deploy model fits single-server sites.
- **Alternative technologies:** SVN (centralized), Mercurial, or artifact systems (rsync, plain `scp`).
- **When should we use the alternative?** `rsync` for raw file sync to many machines; artifact repositories (artifactory) for immutable build artifacts that must not be mutated in place.

### 3.6 Bash

- **What is it?** The Bourne-Again shell and scripting language, the default login shell on Ubuntu.
- **Why do we need it?** Every step of setup/deploy is scripted so it is deterministic and reviewable.
- **What problem does it solve?** Turns fragile manual command sequences into idempotent scripts guarded by `set -euo pipefail` and exit codes.
- **What happens without it?** Deploys depend on a human remembering and typing the right 15 commands in the right order.
- **Why was it selected?** It is present on every Ubuntu server (nothing to install) and is the standard for sysadmin automation of this scale.
- **Alternative technologies:** Python, Ansible (config management), `make`, PowerShell (Windows).
- **When should we use the alternative?** Ansible when the infrastructure grows beyond one server and you want declarative state; Python when the automation itself needs real logic/libraries.

## 4. Interaction with the outside world (ports)

| Port | Protocol | Allowed by ufw | Used by |
|---|---|---|---|
| 22 | SSH | yes (`OpenSSH`) | Admin |
| 80 | HTTP | yes (`Nginx Full`) | Public site |
| 443 | HTTPS | yes (`Nginx Full`, rule pre-staged for certbot) | Future TLS |
| 3000 | HTTP | **no** | Backend, loopback only |

The backend binds to `127.0.0.1:3000` specifically so it is unreachable from the internet: ufw never allows 3000 and Nginx proxies to it over loopback.
