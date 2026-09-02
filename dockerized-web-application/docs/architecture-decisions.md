# Architecture Decision Records (ADRs)

Each entry: **Decision / Why / Alternatives / Why not / Consequences**.

---

## ADR-001: Containerize the application

- **Decision:** Package the Node.js app into a Docker image and run it as a container.
- **Why:** Reproducibility ("works on my machine" is eliminated), isolated dependencies, identical behavior across dev/test/prod, and easy horizontal scaling by running more container replicas.
- **Alternatives:** Run directly on the host via systemd; run inside a VM.
- **Why not:** Host-level runs suffer from version drift and inconsistent environments; VMs carry a full OS per instance (slower start, more resources).
- **Consequences:** Requires Docker on the target host; adds image build + registry management; OS/kernel must support container isolation.

## ADR-002: Multi-stage Dockerfile

- **Decision:** Build the image with two stages — `builder` (tooling) and `runtime` (slim, non-root).
- **Why:** Only runtime artifacts ship; build tooling, caches, and intermediate files never enter the final image, shrinking size and attack surface.
- **Alternatives:** Single-stage Dockerfile; external build server producing artifacts.
- **Why not:** A single stage ships compilers/packagers you don't need at runtime; an external build server adds CI complexity.
- **Consequences:** Slightly more complex Dockerfile; layer caching of `COPY` still works; image size stays small (~50 MB for this app).

## ADR-003: Docker Compose for orchestration

- **Decision:** Define all services (nginx, app, db) in one `docker-compose.yml` and drive them with `docker compose`.
- **Why:** One command (`up -d`) creates networks, volumes, and containers in the right order; config lives in versioned YAML instead of many `docker run` commands.
- **Alternatives:** A shell script of `docker run` calls; Kubernetes; Docker swarm.
- **Why not:** Scripts are unreadable and unmaintainable; Kubernetes is far too heavy for a single-node demo project; swarm is legacy.
- **Consequences:** Requires Docker Compose plugin (bundled with Docker Desktop); team must follow YAML conventions; still needs a real orchestrator for production scale-out.

## ADR-004: Nginx as reverse proxy in front of the app

- **Decision:** Put an `nginx:alpine` container in front of the Node app, terminating HTTP on port 80 and proxying to `app:3000`.
- **Why:** Clean external entry point, central place for TLS, caching, gzip, header injection, and later load-balancing across multiple app replicas; also lets the app not bind privileged ports.
- **Alternatives:** Let the app listen directly on 80; use Node's own `cluster`/`http.createServer` as the front; Traefik/Caddy.
- **Why not:** Binding 80 directly to Node works but mixes concerns and prevents a smooth path to multi-replica load balancing; Traefik/Caddy add a learning curve not needed here.
- **Consequences:** One more container to run/monitor; nginx becomes a (minor) single point of failure unless replicated; healthchecks must account for the proxy hop.

## ADR-005: PostgreSQL in a container

- **Decision:** Run PostgreSQL 16 in a container rather than as a host service.
- **Why:** Version-pinned database that any teammate can start instantly; matches the "everything is code" story; no host install/config.
- **Alternatives:** Host-managed PostgreSQL; managed cloud DB (RDS, Cloud SQL).
- **Why not:** A host DB reintroduces setup drift; a managed cloud DB is overkill and costs money for a local demo.
- **Consequences:** DB lifecycle is tied to the container; must use a named volume for persistence (see ADR-006); production would likely prefer a managed service.

## ADR-006: Named volume for persistence

- **Decision:** Persist PostgreSQL data in the named volume `pgdata`, mounted at `/var/lib/postgresql/data`.
- **Why:** Container filesystems are ephemeral — deleting a container wipes data. A named volume survives `compose down` (without `-v`) and is easy to back up/migrate.
- **Alternatives:** Bind mount a host directory; no volume (in-memory only).
- **Why not:** Bind mounts couple the config to host paths (less portable); no volume means data loss on every restart.
- **Consequences:** `docker compose down -v` permanently deletes data — must be flagged as destructive; volume lifecycle must be documented and monitored.
