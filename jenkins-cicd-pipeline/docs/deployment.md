# Deployment

How a change gets from a developer's laptop to a running container, what happens when things fail, and how to roll back.

## The deploy path

```
Developer push ──► GitHub ──► Jenkins (webhook/poll) ──► Pipeline ──► docker build ──► docker run ──► health check
```

There is **no separate deployment machine** in this demo: deployment *is* the `Docker Run` stage — Jenkins starts the freshly built container on the Docker host and verifies it is healthy before reporting success.

## Full pipeline walkthrough (one commit)

1. **Checkout** — Jenkins clones the repo at the exact commit (`GIT_COMMIT`).
2. **Build & Validate** — `node --version`, `node --check server.js` (syntax gate), verifies zero dependencies.
3. **Test** — `node --test` runs the real HTTP tests against a live in-process server.
4. **Security Check** — Trivy scans the image; with `--exit-code 0` it reports but never blocks (gate off by default; flip to 1 to enforce).
5. **Docker Build** — `docker build -t hello-app:<BUILD_NUMBER> ./app`, also tagged `latest`.
6. **Docker Run** — `docker run -d --name hello-app-<N> -p 809<N%10>:3000 hello-app:<N>`, then a bounded wait loop until `/health` answers.
7. **Health Check** — `curl /health` must contain `"status":"ok"`, else the stage fails.
8. **Cleanup** — container removed (best-effort), `post.always` re-confirms.
9. **Result** — `post.success`/`post.failure` messages; Blue Ocean shows the run visually.

## Failure handling

| Stage | Typical failure | What Jenkins does | You do |
| --- | --- | --- | --- |
| Checkout | Bad SCM URL / credentials | Stage red, build stops | Fix repo URL or credential |
| Build | Syntax error | Red at Build stage | Fix `server.js`, push |
| Test | `EXPECTED` toggled to `fail` | Red at Test stage, console shows the failing assertion | Fix test, push |
| Security | Trivy finds CRITICAL (if gating on) | Red (when `--exit-code 1`) | Update base image / deps |
| Docker Build | Base image pull fail / bad Dockerfile | Red at Docker Build | `docker pull node:24-alpine`, check Dockerfile |
| Docker Run | Port clash 809N | Red — container never starts | Clean up `docker ps`, `docker rm -f` |
| Health Check | App crash / wrong port | Red at Health Check, `UNHEALTHY` message | Read `docker logs hello-app-N` |

**Post-condition guarantee:** because cleanup runs in `post.always`, a failed build never leaves a running container behind (except the app you started manually).

## Rollback

The pipeline is **immutable-per-build**: every build produces `hello-app:<BUILD_NUMBER>`. To roll back to the last known-good commit:

```bash
git revert HEAD
git push origin main          # webhook fires → Jenkins rebuilds previous good code
```

- Jenkins builds the **reverted** commit; that image becomes `hello-app:<new-N>` and is health-checked before the build succeeds.
- If you had also pushed images to a registry, rollback = re-run the pipeline on the old commit (or `docker run hello-app:<old-N>` directly from history).
- Local container rollback (dev): `docker rm -f hello-app-1 && docker run -d --name hello-app-1 -p 8091:3000 hello-app:<old-build>`.

## Deploying to real environments (beyond this demo)

- **Push image to a registry** (Docker Hub / GHCR / ECR) after the Security stage, tag with git SHA.
- **Deploy step**: replace the local `docker run` with `docker pull` + `docker stop/run` on the target host, or a container orchestrator (Kubernetes / Docker Swarm).
- **Blue/green**: keep `v-old` running while `v-new` passes health checks, then switch traffic.
- **Immutable tags**: tag with git SHA, never overwrite `latest` blindly.

## What was validated in this repo

- `node --check server.js` and `node --test` run green locally with **zero npm dependencies** (see validation notes at the bottom of the README).
- The compose file validates with `docker compose config`.
- The full end-to-end Jenkins run requires Docker + Jenkins running locally; the `scripts/run-pipeline.sh` launcher automates the Jenkins startup portion.
