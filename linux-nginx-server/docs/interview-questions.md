# Interview Questions

> Concise, technically accurate answers for the stack in this project (Linux, Bash, Git, SSH, Nginx, systemd, ufw). **Documented, not executed** — these are reference answers, not outputs from a live server.

## Beginner

### 1. Why do we use Linux for servers?

Linux is open source, stable, lightweight, and dominates server hosting. It boots fast, uses few resources, stays up for months between reboots, and comes with a mature package manager (`apt`) and toolchain. Nearly all hosting providers and cloud platforms run Linux, and most server tooling — Nginx, Docker, Kubernetes — targets it first. The permission model (users, groups, `rwx`) also gives granular, auditable control that is hard to match on Windows for headless workloads.

### 2. What is a web server, and what does Nginx specifically do?

A web server is software that listens on an HTTP port (80/443), accepts browser requests, and returns responses (HTML, assets, or proxied application output). Nginx does two jobs here: it serves static files directly from disk (`root /var/www/hello-web`) very fast, and it acts as a reverse proxy — forwarding `/api` requests to a backend on `127.0.0.1:3000` and returning the backend's response. Its event-driven model handles many concurrent connections with few processes.

### 3. How do you read the permissions in `ls -la`?

The first field is 10 characters: type + 3 triplets. Example `drwxr-xr-x`: `d` = directory, owner has `rwx`, group has `r-x`, others have `r-x`. `r`=read(4), `w`=write(2), `x`=execute(1), so the mode is 755. Files (`-rw-r--r--` = 644) are readable by everyone, writable only by the owner; directories need `x` to be entered. That is why configs are 644/600 and scripts 755.

### 4. What is SSH used for, and how is it more secure than a password login?

SSH is the encrypted protocol for remote shells, file transfer (`scp`), and tunneling. Instead of a password sent over the wire (or guessed by bots), a public-key pair proves identity: the server has the public key and challenges the client, which signs with the private key. The private key never leaves the laptop. Combined with `PasswordAuthentication no`, there is nothing left to brute-force.

## Intermediate

### 5. What is a reverse proxy?

A reverse proxy sits in front of one or more backend servers and forwards client requests to them. Here, Nginx listens on port 80; any `/api` request is forwarded to `127.0.0.1:3000` via `proxy_pass`, and the backend's response is returned to the client. Benefits: the backend is hidden from the internet (no exposed port), one public entry point handles TLS/load balancing/caching, and backends can move/scale without clients noticing.

### 6. What is systemd, and what is a unit file?

systemd is the init system (PID 1) that boots Ubuntu and supervises services. A unit file is a declarative description of a service: `systemd/hello-web.service` defines `After=network.target`, the `ExecStart` command, the `User=`/`Group=`, `Restart=on-failure`, `RestartSec=3`, and `WantedBy=multi-user.target` (start at boot). `systemctl enable --now hello-web` activates it now and at boot; `Restart=on-failure` makes systemd bring it back if it crashes.

### 7. `chmod 755` vs `chmod 644` — when would you use each?

`755` (`rwxr-xr-x`): owner can read/write/execute, everyone else can read/execute — correct for scripts and executable binaries (`scripts/*.sh`, `tests/smoke-test.sh`). `644` (`rw-r--r--`): owner can read/write, everyone else can only read — correct for web content and configs (`index.html`, `hello-site.conf`) where nobody should execute or modify them at runtime. Anything sensitive uses `600` (owner only).

### 8. What is a port, and how do you check what is listening?

A port is a numbered endpoint (0–65535) that lets one IP host many services; a client connects to `IP:port`. In this project 22=SSH, 80=HTTP, 443=HTTPS, 3000=the backend. To see listeners: `ss -ltnp` (or `netstat -ltnp`) shows each listening socket, the address it binds, and the owning process. That is the first tool for "port already in use" and "is the backend really on loopback?" questions.

## Advanced

### 9. Walk through how you would troubleshoot a 502 Bad Gateway.

1. Confirm the scope: does `/api/` fail while the static page works? That isolates the proxy path.
2. Check the upstream directly: `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3000/`. Non-2xx/refused ⇒ the backend, not Nginx.
3. Check the backend service: `systemctl status hello-web` and `journalctl -u hello-web -n 50` (did it crash? is it bound to 127.0.0.1:3000?).
4. Check Nginx's view: `tail -n 20 /var/log/nginx/error.log` — look for `connect() failed (111: Connection refused)` or a timeout.
5. Fix and verify: restart the unit (`systemctl restart hello-web`) or fix `proxy_pass`/bind, then re-run the smoke test.

### 10. How do you make a service auto-restart on failure with systemd?

Set `Restart=on-failure` and `RestartSec=3` in the `[Service]` section of the unit file, then `sudo systemctl daemon-reload` (required after any unit edit) and `sudo systemctl restart hello-web`. With `on-failure`, systemd restarts the unit when it exits non-zero or crashes, but not on a clean stop (useful when stopping the service intentionally). `always` restarts even on clean exits. `WantedBy=multi-user.target` makes it start at boot.

## Scenario

### 11. The website is down. You have no prior context. What do you do?

In order, using only read-only diagnostics first:
1. `systemctl status nginx` — is the service running or failed?
2. `curl -I http://127.0.0.1/` — does the local HTTP port answer?
3. `tail -n 50 /var/log/nginx/error.log` and `journalctl -u nginx -n 50` — what did Nginx complain about?
4. `ss -ltnp | grep ':80'` — is another process squatting on port 80?
5. `df -h` and `tail -n 5 /var/log/syslog` — is the disk full? Did the box reboot?
6. From outside: `curl -I http://SERVER_IP/` and `sudo ufw status verbose` — can you even reach the box, or is the firewall dropping you?
Only after the cause is identified do you act (start/restart nginx, fix the bind, free disk space, adjust ufw), then confirm with the smoke test.

### 12. `sudo systemctl start nginx` fails with "bind() to 0.0.0.0:80 failed". What next?

Port 80 is already taken. Find the owner: `ss -ltnp | grep ':80'`. Likely culprits: Apache left over from the image, or a duplicate `listen 80` in sites-enabled. Stop/disable the other web server (`systemctl stop apache2 && systemctl disable apache2`), or remove the duplicate `sites-enabled` entry, then `sudo nginx -t` and `sudo systemctl start nginx`. This is exactly why the troubleshooting runbook keeps "port already in use" and the `bind() failed` case as separate entries — same root cause, different symptoms.
