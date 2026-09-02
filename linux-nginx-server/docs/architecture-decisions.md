# Architecture Decision Records

> **Documented, not executed.** These ADRs record why each technology was chosen for this project, the alternatives considered, and the trade-offs accepted. The records here are the actual decisions; no code was deployed to a live server for this deliverable.

---

## ADR-001: Nginx as the web server

**Decision:** Serve the static hello site with Nginx (event-driven, single config), and use Nginx as the reverse proxy for `/api`.

**Why:** Nginx serves static files extremely efficiently with a very small memory footprint, scales to thousands of concurrent connections on one worker process, and its `proxy_pass` / `location` model makes the optional reverse proxy a config change rather than new software. It is available in the Ubuntu repos (`apt install nginx`) and is the most common web server on the public internet.

**Alternatives:**
- Apache httpd
- Caddy
- Serving directly from a language HTTP server (Node/Express, Python/http.server)

**Why not:**
- Apache: more config surface and heavier per-connection model for pure static + reverse-proxy workloads; `.htaccess` support is irrelevant here because config is managed by git.
- Caddy: superb UX and automatic TLS, but adds an extra binary/framework and hides some of the HTTP mechanics this project is meant to teach.
- Language HTTP server directly: loses a separate web tier, makes static+proxy coupling, and gives away the event-driven performance and logging that Nginx provides for free.

**Consequences:**
- One more process tier to manage — offset by the fact that Nginx is bulletproof and its config lives in git.
- TLS needs certbot/ACME integration later (Nginx does not auto-issue certificates like Caddy).
- Static files are served directly; the backend is only involved for `/api`.

---

## ADR-002: systemd as the init/service manager

**Decision:** Manage the demo backend (and rely on systemd for Nginx) with unit files, `systemctl`, and `journalctl`.

**Why:** systemd is the default init on Ubuntu — nothing extra to install. Its unit model gives declarative dependencies (`After=network.target`), crash recovery (`Restart=on-failure`, `RestartSec=3`), boot ordering (`WantedBy=multi-user.target`), and centralized logging through `journalctl`.

**Alternatives:**
- SysV init scripts
- Upstart (pre-16.04 Ubuntu)
- runit
- supervisord

**Why not:**
- SysV/Upstart: legacy; no declarative restart policy, no `journalctl`, and upstream distros have moved on.
- runit: excellent for minimal/container environments, but non-standard on Ubuntu and not installed by default.
- supervisord: aimed at supervising processes inside environments without a modern init (e.g., some containers/`venv`); redundant here where systemd already exists.

**Consequences:**
- Vendor lock to systemd's unit syntax (which is the Ubuntu default anyway).
- Logs route through journald, so `journalctl` becomes part of the mental model.
- Adding `hello-web.service` is a single file drop + `daemon-reload`.

---

## ADR-003: ufw as the host firewall

**Decision:** Use ufw (Uncomplicated Firewall) with default-deny incoming and explicit allows for `OpenSSH` and `Nginx Full`.

**Why:** ufw is the standard, packaged firewall front-end on Ubuntu (`apt install ufw`). Its rule syntax is human-readable, it wraps nftables/iptables reliably, and `ufw status verbose` gives an instant audit view. Default-deny incoming + allow-listing 22/80/443 is the correct posture for a public single-server deployment.

**Alternatives:**
- Raw `nftables`/`iptables` directly
- `firewalld`
- A cloud security group alone

**Why not:**
- Raw nftables/iptables: powerful but verbose and easy to get wrong; the extra power is not needed for a two-rule policy.
- firewalld: RHEL-oriented, less idiomatic on Ubuntu.
- Cloud security group alone: still worth having, but the host firewall is the last line of defense independent of the provider console.

**Consequences:**
- Policy lives in a simple ordered list — easy to review, easy to reproduce in scripts (`install-server.sh`).
- Lockout risk if the SSH rule is not added before `ufw enable` — mitigated by ordering the script and keeping the provider console as an escape hatch.

---

## ADR-004: SSH for remote administration

**Decision:** Administer the server exclusively over SSH with public-key authentication; disable password auth and root login after key setup.

**Why:** SSH is the de-facto standard remote admin protocol on Linux — every VPS provider supports it natively, it is encrypted end-to-end, and it carries not just shells but file transfer (`scp`) and git over the same authenticated channel. Key-based auth removes the password-guessing attack surface almost entirely.

**Alternatives:**
- telnet (unencrypted)
- Provider web consoles only
- VPN + RDP / vendor remote access

**Why not:**
- telnet: plaintext credentials over the network — never acceptable on a public box.
- Web console only: no scripting, no `scp`, and every operation is manual and slow.
- RDP/VPN: Windows-centric, heavyweight; does not match a headless Linux box.

**Consequences:**
- If the private key is lost, access depends on the provider console — hence keeping that path documented.
- Public keys must be installed and perms kept tight (`600`/`700`); lockout risk handled with careful ordering of hardening steps.

---

## ADR-005: Static file deployment via git

**Decision:** Make GitHub the source of truth and deploy by `git pull` + copy into the web root, with `nginx -t` gating every config change and `smoke-test.sh` verifying each deploy.

**Why:** For a static site + config repo, git gives versioning, an audit trail, collaboration, and — critically — rollback (`git checkout <tag> -- web/`) for zero extra tooling. Deploying is just moving bytes from a known commit into `/var/www`, so it is fast, deterministic, and fully scriptable.

**Alternatives:**
- `rsync`/`scp` direct file sync
- CI/CD pipeline (GitHub Actions) doing the copy
- Container image (Docker) + registry

**Why not:**
- rsync/scp: no history, no atomic versions, easy to drift between laptop and server.
- CI/CD: valuable, but adds moving parts; the pull model in `deploy-site.sh` already gives a repeatable pipeline that CI can later trigger.
- Containers: heavyweight for a static site; adds registry + runtime complexity with no benefit at this scale.

**Consequences:**
- Deploys are only as good as the repo state — a bad commit can be shipped, mitigated by the `nginx -t` gate and post-deploy smoke test.
- Rollback is instant and audit-friendly (a rollback is itself recorded in git).
- Secrets must never enter the repo — enforced by `.gitignore` (see `docs/security.md`).
