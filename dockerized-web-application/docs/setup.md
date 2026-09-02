# Setup Guide

## Prerequisites

| Tool | Version | Why |
|------|---------|-----|
| Docker Desktop / Docker Engine | 24+ (Compose v2) | Runs images and `docker compose` |
| Git | any | Clone/version the project |
| Bash (Git Bash / WSL / macOS / Linux) | any | Run `scripts/*.sh` and `tests/test-api.sh` |
| Node.js (optional, local-only) | 18+ | Syntax-check `server.js` without Docker |

> **Validation note:** Authoring machine had Docker CLI and Node available but
> no running daemon, so this guide's build/run steps are **documented**, not
> executed. They follow standard Compose behavior.

## 1. Clone / enter the project

```bash
cd "D:\Codeing\github\devops project\dockerized-web-application"
```

## 2. Create the environment file

```bash
cp .env.example .env
```

Then edit `.env` and set a real password for `DB_PASSWORD`. Keep the other
values as-is — `DB_HOST=db` must match the compose service name.

## 3. Verify Docker is running

```bash
docker --version
docker info          # must not print "Cannot connect to the Docker daemon"
```

## 4. Validate the compose file

```bash
docker compose config
```

Expected: the effective config (env vars interpolated) printed with no errors.
This step confirms YAML indentation, service definitions, and env references.

## 5. Build the app image

```bash
docker compose build
```

Expected: `node:22-alpine` pulled once, then two stages run (builder syntax
check → runtime copy) and `dockerized-app:latest` is tagged.

## 6. Start the stack

```bash
docker compose up -d
```

Expected: network `appnet` and volume `pgdata` created; containers start in
order — `db` becomes healthy first, then `app`, then `nginx`.

## 7. Verify health

```bash
docker compose ps
curl -sS http://localhost/health
```

Expected: all three services `Up (healthy)`, and curl prints
`{"status":"ok"}`.

## 8. Explore

```bash
curl -sS http://localhost/                  # HTML page
curl -sS http://localhost/api/message       # JSON + DB connectivity
docker compose logs --tail=30 app           # app logs
```

## 9. Teardown

```bash
docker compose down       # stop, keep pgdata volume
docker compose down -v    # stop AND delete database data — destructive
```

## Local run without Docker (app only)

Requires a local PostgreSQL on `localhost:5432` (or none — the app still runs):

```bash
node app/server.js
```

With no DB reachable, `/health` still returns 200 and `/api/message` reports
`db.status: "not-connected"`. This is the dependency-light fallback that proves
the app runs with zero `npm install`.
