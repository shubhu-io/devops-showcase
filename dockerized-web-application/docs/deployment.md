# Deployment

This guide documents a **CI-style deployment flow** for the dockerized stack.
Commands are documented, not executed on the authoring machine.

## Deployment model

A single Docker host (e.g. a small VPS with Docker Engine) runs the stack.
Images are versioned by git tag; the deployment flow is:

```
git push → CI builds & tests → tag image → deploy on host → health gate
```

## The flow (CI-style)

### 1. Build and test

```bash
git checkout <tag-or-branch>
cp .env.example .env
docker compose build            # build dockerized-app image
bash tests/test-api.sh          # requires stack up; asserts /health 200 + ok, / 200, DB connected
```

### 2. Push the image to a registry (production)

```bash
docker tag dockerized-app:latest registry.example.com/dockerized-app:${GIT_SHA}
docker push registry.example.com/dockerized-app:${GIT_SHA}
```

On the production host, point compose at the registry image instead of a local
build:

```yaml
# production docker-compose.yml (override)
services:
  app:
    image: registry.example.com/dockerized-app:${GIT_SHA}
    build: null
```

### 3. Deploy on the host

```bash
docker compose pull                # fetch the pinned image
docker compose up -d --no-deps app # recreate only the app container
```

### 4. Health gate

```bash
bash scripts/healthcheck.sh        # exits 0 on HTTP 200 from /health
docker compose ps                  # confirm all services healthy
```

If the gate fails, roll back immediately (below). Only then switch DNS/traffic.

## Rollback

Because the app image is immutable and tagged by git SHA, rollback is trivial:

```bash
git checkout <previous-tag>        # or GIT_SHA of the last known-good image
docker compose down                # stop current stack (keeps pgdata volume!)
docker compose up -d --build       # rebuild/restart previous version
bash scripts/healthcheck.sh        # re-verify
```

> Note: `docker compose down` (without `-v`) preserves the `pgdata` volume, so
> database data survives the rollback. Schema migrations are out of scope here.

## Production checklist

- Pin image tags to git SHAs; never deploy `latest`.
- Back up `pgdata` before any risky deploy (`docker run --rm -v ... tar`).
- Use a secrets manager (or at least a deploy-time `.env` outside the repo) for
  `DB_PASSWORD` — never commit real secrets.
- Add a monitoring alert on the `/health` endpoint (see Monitoring in README).
