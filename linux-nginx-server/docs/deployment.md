# Deployment

> **Documented, not executed** — the flow below is real and complete, but was not run against a live server for this deliverable.

## Model

```
Developer commits ──git push──▶ GitHub ──git pull──▶ Server ──copy──▶ /var/www/hello-web ──reload──▶ live site
                                                                          │
                                                            (nginx -t gate before reload)
```

The source of truth is the git repository. The server is a *checkout worker*: it pulls, validates, and copies. It never edits files by hand, so the live site always matches a known commit.

## Flow A — First deployment (from scratch)

1. Clone (one time): `git clone https://github.com/YOUR-USERNAME/YOUR-REPO.git linux-nginx-server`
2. Provision: `sudo bash scripts/install-server.sh`
3. Configure: `sudo bash scripts/setup.sh` (user, web files, nginx config, `nginx -t`, reload)
4. Verify: `bash tests/smoke-test.sh`

## Flow B — Day-to-day deploy

Run `deploy-site.sh` on the server:

```bash
cd ~/linux-nginx-server
sudo bash scripts/deploy-site.sh
```

The script does, in order:

```bash
git pull --ff-only                     # 1. bring in the latest commit (fail if diverged)
mkdir -p /var/www/hello-web
cp -r web/. /var/www/hello-web/        # 2. copy new files into the web root
chown -R webuser:webuser /var/www/hello-web   # 3. keep ownership correct
```

Because the site is static, there is nothing to rebuild — the new `index.html` is live the instant the copy finishes. Nginx does not even need a reload for file changes; `systemctl reload nginx` is only required when a **config** file changes (which is what `setup.sh` does).

## Flow C — Config change (nginx/server block)

1. Edit `nginx/*.conf` locally, commit, push.
2. On the server: `git pull` (or run `deploy-site.sh`).
3. Copy the new config and test **before** activating:

```bash
sudo cp nginx/hello-site.conf /etc/nginx/sites-available/hello-site
sudo nginx -t                          # MUST pass before continuing
sudo systemctl reload nginx            # zero-downtime apply
```

> Rule: **never reload without a passing `nginx -t`.** The failure path in `diagrams/flowchart.mmd` exists precisely because `reload` with a broken config can take the site down.

## Flow D — Rollback

Because every state is a git commit, rollback is just re-deploying an older commit:

```bash
# 1. Inspect history
git -C ~/linux-nginx-server log --oneline -10

# 2a. Revert to the previous deployed commit
git -C ~/linux-nginx-server checkout <previous-good-commit> -- web/ nginx/

# 2b. OR temporarily pin the whole repo to a tag
git -C ~/linux-nginx-server checkout v1.0.1

# 3. Re-run the deploy copy
sudo bash scripts/deploy-site.sh

# 4. Re-apply config if it changed
sudo cp nginx/hello-site.conf /etc/nginx/sites-available/hello-site
sudo nginx -t && sudo systemctl reload nginx

# 5. Verify
bash tests/smoke-test.sh
```

**Recommendation:** tag releases so rollback targets are explicit.

```bash
git tag -a v1.0.1 -m "hello site with footer" && git push origin v1.0.1
```

## Flow E — Backend (reverse-proxy) deployment

The demo backend is a static file server on `127.0.0.1:3000`, so "deploying" it means updating `/var/www/hello-web` and restarting the unit:

```bash
sudo systemctl restart hello-web
systemctl status hello-web --no-pager
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3000/
```

In a real system the backend would be an application (Node/Python/Go); the deploy would additionally install dependencies and rebuild, but the unit file pattern (`Restart=on-failure`, `RestartSec=3`) stays the same.

## Safety checks wired into every deploy

| Gate | Enforced by |
|---|---|
| Latest code, no local drift | `git pull --ff-only` (fails if diverged) |
| Shell scripts parse | `bash -n` (run locally and in CI) |
| Nginx config valid | `nginx -t` before `systemctl reload` |
| Site actually up | `tests/smoke-test.sh` after deploy |
| Automated health | `scripts/healthcheck.sh` in cron: `*/5 * * * * bash /home/deployer/linux-nginx-server/scripts/healthcheck.sh` |

## What is NOT deployed this way

- Secrets: never in the repo. `.env`, `*.pem`, `*.key` are gitignored (see `.gitignore`). Real credentials belong in a secret store / systemd `EnvironmentFile` outside git.
- The server itself: OS packages and users are bootstrapped by `install-server.sh`/`setup.sh`; converting that into Ansible is listed under Future Improvements.
