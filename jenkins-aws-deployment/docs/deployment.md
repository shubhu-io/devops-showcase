# Deployment Guide

This document walks through the exact deploy pipeline, the rollback procedure,
and the blue/green evolution path.

## Pipeline walk-through

Triggered by `git push` (webhook → Jenkins):

1. **Checkout** — Jenkins clones the repo into the workspace (`checkout scm`).
2. **Test** — runs the Node built-in test runner: `node --test` inside `app/`.
   All four tests hit a live server on `127.0.0.1:3000` and assert 200 + JSON.
   A red test aborts the pipeline before any image is built.
3. **Docker Build** — `docker build --build-arg BUILD_VERSION=<BUILD_NUMBER> -t node-app:<N> -t node-app:latest app/`.
   The build version is baked into the image and displayed on the web page.
4. **Security Scan** — Trivy scans the image for HIGH/CRITICAL CVEs. If the `trivy`
   binary isn't installed on the agent, the stage logs a **warning and skips**
   (guard via `command -v trivy`); the build continues.
5. **Transfer Image to EC2** — two modes:
   - **Direct (default, no registry):** `docker save node-app:<N> | ssh ubuntu@IP 'docker load'`.
     The image crosses the wire encrypted by SSH; no Docker Hub account needed.
   - **Registry:** if `USE_REGISTRY=true`, the image is pushed to the configured
     repo (`dockerhub` credential) and the host pulls it.
6. **Deploy to EC2** — Jenkins `scp`s `deploy.sh`, `rollback.sh`, `healthcheck.sh`
   to `/opt/devops/` and runs:
   ```
   IMAGE=node-app:83 BUILD_VERSION=83 PREV_IMAGE_TAG=node-app:82 \
     bash /opt/devops/deploy.sh
   ```
   `deploy.sh` stops the old container, starts the new one with
   `--restart unless-stopped -p 127.0.0.1:3000:3000 -e BUILD_VERSION=83`,
   then runs a local health-check loop against `/health`.
7. **Health Check** — Jenkins also curls `http://EC2_IP/health` from its own side
   (retry loop), confirming the public path: internet → SG :80 → Nginx → container.
8. **post** — on success, logs the deployed tag; on failure, attempts automatic
   rollback to the previous build number's image.

### Exact deploy command Jenkins runs on the host

```bash
docker run -d \
  --name node-app \
  --restart unless-stopped \
  -p 127.0.0.1:3000:3000 \
  -e BUILD_VERSION=83 \
  -e PORT=3000 \
  node-app:83
```

Note the bind `127.0.0.1:3000` — the container is **not** exposed publicly; Nginx
listens on 80 and `proxy_pass`es to it. See [nginx/app-proxy.conf](../nginx/app-proxy.conf).

## Rollback procedure

A "bad deploy" means the new image is broken (crashes, 500s, wrong behavior)
even though it may pass the health check.

**Automatic** — the pipeline's `post { failure }` block calls rollback when Deploy/
Health Check stages fail:

```bash
ssh ubuntu@EC2_IP \
  "TAG=node-app:<previous-build-number> CONTAINER_NAME=node-app APP_PORT=3000 \
   bash /opt/devops/rollback.sh"
```

**Manual** — the same command run by hand after investigating:

```bash
# 1. Confirm current version (bad) and available images
ssh ubuntu@EC2_IP 'docker ps && docker images'

# 2. Roll back to the last known-good tag
ssh ubuntu@EC2_IP 'TAG=node-app:82 bash /opt/devops/rollback.sh'
```

`rollback.sh` stops the bad container, starts the previous tag with the same
port/env/restart settings, health-checks, and prints `ROLLBACK OK: now running
node-app:82`.

### Rollback decision flow

```
Health check fails on :83
        │
        ▼
   rollback to :82  ──healthy──▶ DONE (app back on :82)
        │
        ▼
   :82 also unhealthy ──▶ INCIDENT: docker logs, check disk, check nginx
```

## Blue/green note

The current design is **blue/green-ish with one host**: the old container keeps
running until the new one is about to start, and rollback is a single tag swap.
Two improvements move it to true blue/green:

1. **Two hosts** — deploy the new version to a second EC2 (green), run its health
   checks, then repoint Nginx/ALB traffic to it. Cutover = DNS/ALB change.
2. **Nginx weight trick (single host)** — keep both containers running on
   different ports (`node-app-blue` :3001, `node-app-green` :3002) and flip the
   `upstream` block in `app-proxy.conf` + `nginx -s reload`. Rollback is an instant
   config reload, no container restart.

True blue/green gives near-zero downtime and instant abort. The trade-off: double
compute cost while both versions run, and extra config management. For this
learning project, tag-swap rollback is the pragmatic choice.

## Verifying a deployment

| Check | Command | Expected |
|---|---|---|
| Container up | `ssh ... 'docker ps'` | `node-app` `Up`, port 127.0.0.1:3000->3000 |
| App logs | `ssh ... 'docker logs --tail 50 node-app'` | `[server] listening ... (build: 83)` |
| Public health | `curl -s http://EC2_IP/health` | `{"status":"ok",...}` |
| Version shown | browse `http://EC2_IP/` | build version 83 on the page |
| Nginx ok | `ssh ... 'sudo nginx -t'` | `syntax is ok` |

## Cost note when done

Remember to `aws ec2 terminate-instances --instance-ids <id>` after you're
finished testing, or `stop-instances` if you'll resume later (stopped instances
still charge for EBS volumes but not compute).
