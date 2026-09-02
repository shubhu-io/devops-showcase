# Troubleshooting

> **Documented, not executed** — runbooks below are real diagnostic paths for Ubuntu 22.04/24.04; they were not executed on a live machine for this deliverable.

## 1. Permission denied

**Problem:** Commands or the web server cannot access files/folders (e.g. Nginx returns 403, `cp`/`chmod` fail).

**Cause:** The file owner/group or permission bits do not allow the acting user. Nginx workers run as `www-data`; the web root must be readable by them, and `deploy` scripts need write access as root/`webuser`.

**How to diagnose:**
```bash
ls -la /var/www/hello-web/          # check owner, group, mode
namei -l /var/www/hello-web/index.html   # permissions of every path component
sudo -u www-data test -r /var/www/hello-web/index.html && echo readable
```

**Solution:**
```bash
sudo chown -R webuser:webuser /var/www/hello-web
sudo chmod -R u=rwX,g=rX,o=rX /var/www/hello-web
```

**Prevention:** Keep ownership explicit (`chown` on every deploy — `deploy-site.sh` already does), and never create files in `/var/www` as the wrong user.

## 2. Connection refused

**Problem:** `curl http://127.0.0.1/` → `curl: (7) Failed to connect ... Connection refused`.

**Cause:** Nothing is listening on that port. Either Nginx is not running, or it is bound to a different address/port.

**How to diagnose:**
```bash
systemctl status nginx --no-pager
ss -ltnp | grep ':80'               # is anything listening on 80?
sudo journalctl -u nginx -n 50      # why did it stop?
```

**Solution:** `sudo systemctl start nginx` or fix the bind (see item 3/4), then `sudo systemctl reload nginx`.

**Prevention:** A cron healthcheck (`scripts/healthcheck.sh`) would alert the moment the port stops answering.

## 3. Port already in use

**Problem:** Something else owns port 80 (or 3000); Nginx or the backend cannot bind.

**Cause:** Another process took the port first — e.g. Apache from a previous install, or a second instance of the service.

**How to diagnose:**
```bash
ss -ltnp | grep ':80'
sudo lsof -i :80
```

**Solution:**
```bash
# if the other process is a service you don't need:
sudo systemctl stop apache2 && sudo systemctl disable apache2
# or change one of the servers to another port in its config
```

**Prevention:** On fresh VPS images, remove the default `sites-enabled/default` (setup.sh does this) and audit what starts at boot with `systemctl list-unit-files --state=enabled`.

## 4. `nginx: [emerg] bind() to 0.0.0.0:80 failed (98: Address already in use)`

**Problem:** Nginx refuses to start; the error appears in `journalctl -u nginx` or on `nginx`/`nginx -t` output.

**Cause:** A socket is already bound to `0.0.0.0:80`. This is the "port already in use" case seen from Nginx's side — another nginx instance, Apache, or a leftover process.

**How to diagnose:**
```bash
ss -ltnp | grep ':80'
ps aux | grep -E 'nginx|apache' | grep -v grep
```

**Solution:**
```bash
sudo systemctl stop apache2 2>/dev/null || true
sudo pkill -x nginx          # only if it's a zombie nginx, then:
sudo systemctl start nginx
```

**Prevention:** Test with `nginx -t` before starting, run only one web server, and keep `sites-enabled` free of duplicate `listen 80` blocks.

## 5. 502 Bad Gateway

**Problem:** Nginx answers, but the `/api` route (reverse proxy) returns `502 Bad Gateway`.

**Cause:** Nginx cannot reach the upstream at `127.0.0.1:3000`. Either the backend process is down, it is bound to the wrong address, or the proxy target port/URI is wrong.

**How to diagnose:**
```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3000/   # upstream itself alive?
systemctl status hello-web --no-pager                            # unit state?
ss -ltnp | grep ':3000'                                          # listening on loopback?
tail -n 20 /var/log/nginx/error.log                              # "connect() failed (111)"?
```

**Solution:**
- Backend down → `sudo systemctl restart hello-web` (unit has `Restart=on-failure`).
- Wrong bind → fix `ExecStart` in the unit to `--bind 127.0.0.1`.
- Wrong port in proxy → fix `proxy_pass http://127.0.0.1:3000;`, then `sudo nginx -t && sudo systemctl reload nginx`.

**Prevention:** `Restart=on-failure` for the backend, `proxy_read_timeout` configured, and the healthcheck script covering `/api/`.

## 6. Nginx config test failed

**Problem:** `nginx -t` prints errors like `[emerg] directive is not allowed here` or `unknown directive "server_namex"`.

**Cause:** Syntax or structural error in a config file (missing semicolon, typo in directive, directive used in the wrong context).

**How to diagnose:** `nginx -t` names the file and line:
```bash
sudo nginx -t
# nginx: [emerg] unknown directive "server_namex" in /etc/nginx/sites-enabled/hello-site:6
```

**Solution:** Open the reported file at that line, fix the directive, re-run `sudo nginx -t` until it reports success, then `sudo systemctl reload nginx`.

**Prevention:** Validate before activating: `nginx -t` inside `setup.sh`/deploy scripts, and never reload on a failing test.

## 7. `SSH: Permission denied (publickey)`

**Problem:** `ssh deployer@SERVER_IP` fails with `Permission denied (publickey)` even though you have a key.

**Cause:** The server's `authorized_keys` does not contain your public key, the file has wrong permissions (must be `600`, directory `700`), `AllowUsers`/`PubkeyAuthentication` blocks you, or SELinux-style context issues (RHEL).

**How to diagnose:**
```bash
ssh -v deployer@SERVER_IP     # watch the "Offering public key" / "authentications that can continue" lines
# from the server side (provider console):
sudo tail -n 20 /var/log/auth.log
ls -la ~deployer/.ssh && cat ~deployer/.ssh/authorized_keys
```

**Solution:**
- `ssh-copy-id deployer@SERVER_IP` to install the key.
- Fix permissions: `chmod 700 ~deployer/.ssh && chmod 600 ~deployer/.ssh/authorized_keys`.
- Ensure your key is the one offered: `ssh -i ~/.ssh/id_ed25519 ...`.

**Prevention:** Inject keys at VPS creation, keep `authorized_keys` perms correct, and test `PasswordAuthentication no` last (see `docs/security.md`).

## 8. Service failed to start

**Problem:** `systemctl status hello-web` shows `failed` / `inactive (dead)`, or `systemctl start` errors.

**Cause:** The unit file is invalid, `ExecStart` binary/path is missing, the user in the unit does not exist, or the process exits immediately with an error.

**How to diagnose:**
```bash
systemctl status hello-web --no-pager -l
sudo journalctl -u hello-web -n 50 --no-pager
sudo systemd-analyze verify /etc/systemd/system/hello-web.service
```

**Solution:**
- Missing binary → fix `ExecStart=/usr/bin/python3 -m http.server ...` and confirm `command -v python3`.
- Missing user → `sudo useradd -m -s /bin/bash webuser` (setup.sh does this).
- Invalid unit → fix syntax, then `sudo systemctl daemon-reload && sudo systemctl start hello-web`.
- Immediate exit → fix the underlying runtime error, rely on `Restart=on-failure` only after the app starts cleanly.

**Prevention:** `systemd-analyze verify` in CI, `Restart=on-failure` + `RestartSec=3` for crash recovery, and `daemon-reload` after editing any unit file.

---

## Quick reference: where to look first

| Symptom | First 3 commands |
|---|---|
| Site down | `systemctl status nginx`, `curl -I http://127.0.0.1/`, `tail /var/log/nginx/error.log` |
| 502 on /api | `curl :3000`, `systemctl status hello-web`, `tail /var/log/nginx/error.log` |
| Can't SSH | `ssh -v`, `tail /var/log/auth.log`, `ufw status verbose` |
| Deploy failed | `nginx -t`, `journalctl -u nginx -n 50`, `ls -la /var/www/hello-web` |
