# Security

Security posture for the dockerized stack: keep secrets out of the repo, run
with least privilege, and minimize the attack surface of every image.

## 1. Secrets and `.env` handling

- The repo only ships `.env.example` with the clearly-placeholder password
  `change-me`. The real `.env` is git-ignored (`.gitignore`) and never committed.
- Compose loads `.env` via `env_file` for the app; the db service receives the
  same values through `${DB_USER}` / `${DB_PASSWORD}` interpolation.
- On a shared machine or CI, inject secrets at runtime instead of files:
  - Docker: `docker run --env-file .env ...` or `--env DB_PASSWORD=...` from a
    secret source.
  - Compose: environment overrides, or
    [Docker secrets](https://docs.docker.com/engine/swarm/secrets/) in swarm mode.
- Recommended: a secrets manager (Vault, AWS Secrets Manager, SOPS + git-crypt)
  in production. Never hard-code credentials in Dockerfiles or source.

### Leaked secret drill
If a real password ever lands in a commit, it must be rotated immediately —
git history keeps the secret forever even after the commit is "removed".
Delete the file, rotate the credential, and force-push/rewrite only if the
repo is not public.

## 2. Run as a non-root user

- The runtime stage of the Dockerfile switches to the built-in `node` user
  (`USER node`) so the app never runs as root inside the container.
- Effect: if the app is compromised, the attacker holds a non-root identity
  with no privileges to write outside the app's own layer.
- Guard rails: avoid `USER root` in production images; if a step genuinely
  needs root, do it in the builder stage and switch back before `CMD`.

## 3. Minimal image footprint

- Multi-stage build ships only the runtime stage — no package manager,
  compilers, or build caches (those stay in `builder`).
- Base image `node:22-alpine` is intentionally tiny (~50 MB); smaller images
  mean fewer binaries that can be attacked and faster pulls.
- `.dockerignore` keeps `node_modules`, docs, `.git`, and editor files out of
  the build context so secrets and junk never enter layers.

## 4. Dependency scanning notes

- This app uses zero npm dependencies (built-in `node:http`/`net`), which
  eliminates the npm supply-chain attack surface. If dependencies are added
  later:
  - Scan with `npm audit` (registry advisories) in CI.
  - Scan images with `docker scout quickview` / `docker scout cve <image>`
    (Docker Scout) or Trivy.
  - Pin exact versions (or commit a lockfile) and rebuild frequently to pick
    up patched base images (`apk`/`npm`).
- Keep base image tags pinned to a specific minor (`node:22-alpine`,
  `postgres:16-alpine`, `nginx:alpine`) and subscribe to image update/rebuild
  cycles rather than floating `latest` for production.

## 5. Network isolation

- All services live on the private `appnet` bridge; only nginx publishes a
  host port (80). PostgreSQL's 5432 is **not** exposed to the host — the app
  reaches it by container DNS.
- Principle of least exposure: publish only the ports that must be reachable
  from outside.

## 6. Read-only / hardening opportunities

- Mount nginx config read-only (`:ro`).
- Run containers with `--read-only` rootfs where the app doesn't write
  (advanced; would need a tmpfs for `/tmp`).
- Drop capabilities via compose `cap_drop: [ALL]` and set
  `security_opt: no-new-privileges:true` for the app container in production.
- Terminate TLS at nginx in production (mount certs as read-only secrets).

## References

- [Docker security best practices](https://docs.docker.com/engine/security/)
- [Docker Scout](https://docs.docker.com/scout/)
