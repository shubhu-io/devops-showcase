# Architecture

## Overview

```
User → Nginx (reverse proxy, :80) → Application container (Node.js, :3000) → PostgreSQL container (:5432)
```

All three services run as containers on a custom bridge network called
`appnet`. Postgres data persists in the named volume `pgdata`. A single
`docker compose up -d` builds and starts the whole system.

## Layer by layer

### 1. Client layer (User / Browser)
- Anything that sends HTTP to the host on port 80 — a browser, `curl`, a
  monitoring agent.
- Never talks to the app or database directly; it only knows nginx's address.

### 2. Proxy layer (Nginx, `nginx:alpine`)
- Listens on host port 80. A `default.conf` (mounted read-only from
  `./nginx/default.conf`) declares an `upstream` pointing at `app:3000`.
- `location /` proxies all traffic with standard forwarding headers
  (`X-Real-IP`, `X-Forwarded-For`, `Host`); `location = /health` is a dedicated
  health route; gzip compression is enabled.
- Starts only after the app is healthy (`depends_on: app:
  condition: service_healthy`).
- Benefits: clean external entry point, one place to later add TLS, caching,
  rate limiting, and load balancing across app replicas.

### 3. Application layer (Node.js, `node:22-alpine`, non-root `node` user)
- Dependency-light HTTP server using only Node built-ins (`http`, `net`, `url`).
- Routes (module `app/src/routes.js`):
  - `GET /` — HTML hello page.
  - `GET /health` — `{"status":"ok"}` used by the Docker healthcheck.
  - `GET /api/message` — JSON message plus live DB connectivity status
    (attempts a TCP connect to the configured `DB_HOST:DB_PORT`).
- Config via environment variables: `PORT`, `DB_HOST`, `DB_PORT`, `DB_USER`,
  `DB_PASSWORD`, `DB_NAME` (values from `.env`, loaded by compose).
- Built by a multi-stage Dockerfile (builder validates syntax → runtime copies
  only the source and runs as `node`); the image declares a `HEALTHCHECK`
  against `/health`.
- The app does not listen on the host — only nginx publishes its port.

### 4. Data layer (PostgreSQL, `postgres:16-alpine`)
- Credentials and DB name come from the same `.env` via `POSTGRES_USER`,
  `POSTGRES_PASSWORD`, `POSTGRES_DB` (only applied on first init).
- `database/init/01-init.sql` is mounted into
  `/docker-entrypoint-initdb.d/` and runs once, creating the `messages` table
  and seeding a row.
- Data is written to the named volume `pgdata` at
  `/var/lib/postgresql/data` so it survives container restarts.
- Exposed to the app network only (port 5432 is not published to the host).

### 5. Platform layer (Docker engine + Compose)
- `docker-compose.yml` wires everything: services, build context, image tags,
  env file, healthchecks, `depends_on` ordering, custom network `appnet`, and
  the `pgdata` volume.
- Networking: a custom bridge network with embedded DNS — services reach each
  other by name (`nginx → app → db`), no host port needed for DB access.

## Technology: Docker

- **What is it?** A platform for packaging applications into images and running
  them as isolated containers on a shared kernel.
- **Why do we need it?** It makes the environment part of the artifact: code +
  runtime + config travel together.
- **What problem does it solve?** Environment drift and "works on my machine" —
  every dev, CI, and server runs the exact same bits.
- **What happens without it?** Manual setup per machine, version conflicts,
  inconsistent behavior between environments.
- **Why was it selected?** De-facto industry standard for containers, massive
  ecosystem, trivial install via Docker Desktop.
- **Alternative technologies:** Podman, containerd + custom tooling, Vagrant/VMs.
- **When should we use the alternative?** Podman for rootless/no-daemon needs;
  VMs when you need a different kernel or stronger isolation.

## Technology: Dockerfile

- **What is it?** A declarative recipe that defines how a Docker image is built.
- **Why do we need it?** To codify the image: base image, files, env, user,
  healthcheck, start command.
- **What problem does it solve?** Reproducible images — anyone can rebuild the
  exact same artifact from source.
- **What happens without it?** Hand-assembled, inconsistent images; no audit
  trail of how the image was made.
- **Why was it selected?** It is the standard Docker build mechanism and works
  seamlessly with Compose.
- **Alternative technologies:** BuildKit features like Dockerfiles with
  secrets/cache mounts (this project uses BuildKit via `syntax=docker/dockerfile:1`);
  OCI images built by `buildah` or `kaniko`.
- **When should we use the alternative?** Kaniko/buildah when building images
  inside Kubernetes clusters without a Docker daemon.

## Technology: Docker Compose

- **What is it?** A YAML-based tool for defining and running multi-container
  applications.
- **Why do we need it?** Our stack is three containers with shared network,
  volume, env, and ordering — too much to express with raw `docker run`.
- **What problem does it solve?** Single-command, reproducible orchestration for
  local dev and CI, with the whole topology versioned as code.
- **What happens without it?** Dozens of error-prone shell commands and no
  clear description of the system.
- **Why was it selected?** Bundled with Docker Desktop, zero extra moving parts
  for this project size.
- **Alternative technologies:** Kubernetes, Docker swarm, plain scripts.
- **When should we use the alternative?** Kubernetes when you need production
  autoscaling/self-healing across nodes; scripts when the app is one container.

## Technology: Nginx

- **What is it?** A high-performance web server and reverse proxy.
- **Why do we need it?** To be the single external entry point on port 80 in
  front of the app.
- **What problem does it solve?** Separation of concerns: the app stays on an
  internal port; TLS, compression, headers, and later load balancing live in
  one place.
- **What happens without it?** The Node app would bind a public port directly,
  mixing app logic with edge concerns and complicating scaling to replicas.
- **Why was it selected?** Proven, extremely fast, tiny Alpine image, trivial
  config.
- **Alternative technologies:** Caddy, Traefik, HAProxy, Node itself.
- **When should we use the alternative?** Caddy/Traefik for automatic TLS
  certificates; HAProxy for advanced layer-4 routing.

## Technology: PostgreSQL

- **What is it?** A mature open-source relational database.
- **Why do we need it?** To store the app's persistent data (the `messages`
  table) outside the ephemeral app container.
- **What problem does it solve?** Durable, queryable storage that survives app
  restarts and is decoupled from app code.
- **What happens without it?** Data would live in the container filesystem and
  vanish on recreate — or the app would not demonstrate DB integration at all.
- **Why was it selected?** Industry-standard RDBMS, official Alpine image,
  robust features, easy to containerize.
- **Alternative technologies:** MySQL/MariaDB, MongoDB, SQLite, managed clouds.
- **When should we use the alternative?** MongoDB for flexible document models;
  managed clouds (RDS/Cloud SQL) for zero-ops production with backups/HA.
