# Troubleshooting

Each entry follows: **Problem / Cause / How to diagnose / Solution / Prevention**.

## 1. Cannot connect to the Docker daemon

- **Problem:** Every `docker ...` command fails with `Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?` (Linux) or `error during connect ... open //./pipe/docker_engine` (Windows).
- **Cause:** The Docker engine is not running, or the current user lacks permission to the socket.
- **How to diagnose:** `docker --version` works (client) but `docker info` fails. On Windows check the Docker Desktop tray icon; on Linux run `systemctl status docker`.
- **Solution:** Start Docker (Docker Desktop on Windows/macOS; `sudo systemctl start docker` on Linux). On Linux, add your user to the `docker` group: `sudo usermod -aG docker $USER` then re-login.
- **Prevention:** Ensure Docker Desktop launches at login or enable `systemd` autostart for the docker service.

## 2. Port is already allocated / port already in use

- **Problem:** `docker compose up` fails with `Error response from daemon: driver failed programming external connectivity ... Bind for 0.0.0.0:80 failed: port is already allocated`.
- **Cause:** Another container or host process already binds port 80 (or 3000/5432).
- **How to diagnose:** `docker ps -a` to spot another container; on Windows `netstat -ano | findstr :80`.
- **Solution:** Stop the conflicting container (`docker stop <name>`), or change the host port mapping in `docker-compose.yml` (e.g. `"8080:80"`).
- **Prevention:** Pick less-common host ports (e.g. 8080) or document the ports in use in the README.

## 3. Container exits immediately

- **Problem:** `docker compose ps` shows `app-node ... Exited (1)` seconds after startup.
- **Cause:** The app crashed on boot — often a missing module, bad env var, or the working directory/command is wrong.
- **How to diagnose:** `docker logs app-node`; it will print the actual error, e.g. `Error: Cannot find module`.
- **Solution:** Fix the cause shown in logs. For this project confirm `.env` exists (compose reads it) and the healthcheck port matches `PORT`.
- **Prevention:** Run `node --check server.js` in CI and set `restart: unless-stopped` so crashes are visible but auto-restarted.

## 4. Error response from daemon: pull access denied

- **Problem:** `docker compose up` fails with `pull access denied for postgres:16-alpine, repository does not exist or may require 'docker login'`.
- **Cause:** Image name/tag typo, or the image requires an authenticated registry.
- **How to diagnose:** Verify the tag: `docker search postgres`; check for typos (`postgres` vs `postgresql`, wrong tag like `postgres:latest` vs `postgres:16-alpine`).
- **Solution:** Use the correct public tag `postgres:16-alpine`. If it is a private registry, run `docker login <registry>` first.
- **Prevention:** Pin exact tags that are verified on Docker Hub and keep the registry hostname explicit.

## 5. Nginx 502 Bad Gateway

- **Problem:** `curl http://localhost` returns `502 Bad Gateway` from Nginx.
- **Cause:** Nginx is up but cannot reach the `app` container — the app is down, not healthy, or the upstream name/port is wrong.
- **How to diagnose:** `docker compose ps` (is `app-node` healthy?), `docker compose logs app`, then inside nginx: `docker exec app-nginx wget -qO- http://app:3000/health`.
- **Solution:** Ensure `depends_on: app: condition: service_healthy` in compose, confirm `upstream app_backend { server app:3000; }` matches the app container name and `PORT=3000`.
- **Prevention:** Keep the healthcheck so nginx never starts before the app is ready; keep container names stable.

## 6. Healthcheck failing

- **Problem:** `docker compose ps` shows `app-node ... Up (unhealthy)`.
- **Cause:** The healthcheck command fails inside the container — wrong path, port mismatch, or the app is slow to boot.
- **How to diagnose:** `docker inspect app-node --format '{{json .State.Health}}'` and read the log/message of the last check; run the command manually: `docker exec app-node wget -qO- http://127.0.0.1:3000/health`.
- **Solution:** Match the healthcheck to the actual app (path `/health`, port `3000`). Increase `start_period` for slow starts. Use `CMD` form for `wget`, `CMD-SHELL` for compound shell commands.
- **Prevention:** Always test the healthcheck command manually before wiring it into compose.

## 7. Module not found when running server

- **Problem:** `node server.js` fails with `Error: Cannot find module 'express'` (or any package).
- **Cause:** The code `require()`s an external package that was never installed, or `node_modules` was not copied into the image.
- **How to diagnose:** Read the stack trace; `docker exec app-node ls node_modules` to confirm.
- **Solution:** This project uses only built-in `http`/`net`/`url` modules — no install needed. If you add dependencies, run `npm ci` in the builder stage and copy `node_modules` (or use `npm ci --omit=dev`) into the runtime stage.
- **Prevention:** Keep the app dependency-light; document required packages in `package.json` and always test `node --check` + a local run before building.

## 8. PostgreSQL password authentication failed

- **Problem:** App logs show `password authentication failed for user "appuser"` or a connection refused because env vars are empty.
- **Cause:** `.env` values differ between what Postgres was initialized with and what the app uses — Postgres only reads `POSTGRES_*` on first init of an empty volume.
- **How to diagnose:** `docker compose exec db env | grep POSTGRES`; `docker compose config` to see the effective values; check whether `pgdata` volume already exists.
- **Solution:** Keep `.env` consistent (`DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_HOST=db`, `DB_PORT=5432`). If the volume was initialized with old credentials: `docker compose down -v && docker compose up -d`.
- **Prevention:** Never change DB credentials after the first `up` without recreating the volume; document that `down -v` is destructive.

## 9. Permission denied when binding port

- **Problem:** `docker run -p 80:80 ...` fails on Linux with `bind: permission denied` or `Operation not permitted`.
- **Cause:** Ports below 1024 (privileged ports) require root, or an SELinux/AppArmor restriction.
- **How to diagnose:** Try `-p 8080:80`; if it works the issue is the privileged port.
- **Solution:** Map to a high host port (`"8080:80"`), or configure an unprivileged proxy like `authbind`/iptables (advanced).
- **Prevention:** In development, avoid privileged host ports; document this in setup.md.

## 10. Docker build fails at RUN step

- **Problem:** `docker compose build` stops with a non-zero exit in a `RUN ...` line.
- **Cause:** The command itself fails (typo, wrong base image tools, network during `apk add`), or the copied file isn't where the step expects.
- **How to diagnose:** Read the step number and error; add `--progress=plain` for full output. Test the RUN command in a scratch container: `docker run --rm -it node:22-alpine sh`.
- **Solution:** Fix the command or Dockerfile order (copy files before using them, install tools in the builder). If it's a transient network issue, retry.
- **Prevention:** Keep `RUN` steps deterministic; pin base image tags; run syntax checks (`node --check`) as a build-time gate.

## 11. Image pulls forever / DNS resolution

- **Problem:** `docker pull nginx:alpine` hangs, or fails with `Get https://registry-1.docker.io/...: dial tcp: lookup registry-1.docker.io: no such host`.
- **Cause:** Network/DNS issue on the host, or a blocked/proxied registry.
- **How to diagnose:** `ping registry-1.docker.io`; `curl -sI https://registry-1.docker.io/v2/`; check corporate proxy settings.
- **Solution:** Fix DNS (`nslookup`), configure Docker's proxy in daemon settings, or pull via a mirror registry configured in `/etc/docker/daemon.json`.
- **Prevention:** Document required egress (registry-1.docker.io) for CI environments; consider caching base images on a local registry.
