# GitHub Actions CI/CD

GitHub-hosted CI/CD that lints, tests, builds, and publishes a containerized Node.js app — no Jenkins, no self-hosted runner required.

## Overview

This repository shows the modern counterpart to Jenkins: native GitHub Actions. On push/PR, `ci.yml` checks syntax, runs `node:test`, builds the Docker image, and health-checks it. On version tags (`v*.*.*`) or manual dispatch, `docker-publish.yml` builds for `amd64/arm64` and pushes to `ghcr.io` with provenance, using `GITHUB_TOKEN` OIDC — no static credentials.

**Real-world problem it solves:** teams need gated, reproducible builds without maintaining CI servers; Actions provides caching, attestations, and registry integration out of the box.

```
git push --> Actions: checkout → setup-node → node --check → node --test → docker build → curl /health
git tag v1.0.0 --> docker-publish: login ghcr.io (GITHUB_TOKEN) → buildx → push sha+semver+latest
```

## Architecture

| Workflow | Trigger | Jobs |
|---|---|---|
| `ci.yml` | push/PR to `main` | `lint-test` → `docker-build` (health gate) |
| `docker-publish.yml` | `v*.*.*` or `workflow_dispatch` | `publish` (metadata, login, buildx push) |

`docker-publish.yml` uses `docker/metadata-action` for semver/SHA/latest tags and `gha` cache.

## Technologies

| Technology | Purpose |
|---|---|
| GitHub Actions | CI/CD |
| Docker Buildx | Multi-arch builds |
| GHCR | Container registry (via `GITHUB_TOKEN`) |
| Node.js | App runtime + tests |

## Features

- **Shallow, fast CI** — syntax check + `node --test` + ephemeral `docker run` health probe; no registry needed for PRs
- **Publish** — `linux/amd64,arm64`, layered cache (`gha`), `metadata-action` semver, `provenance` via `build-push-action`
- **OIDC auth** — `permissions: packages: write` + `GITHUB_TOKEN`, no long-lived PAT
- **Reusable locally** — `docker build -t app:ci ./app && bash scripts/healthcheck.sh`

## Prerequisites

- GitHub repository (enable Actions)
- For local run: Docker, Node 18+, Bash

## Setup

```bash
git clone <this-repo> && cd github-actions-cicd
# No .env needed; GHCR auth uses GITHUB_TOKEN in Actions
docker build -t app:ci ./app
docker run -d -p 3000:3000 app:ci
curl http://localhost:3000/health
```

In GitHub: Settings → Actions → General → Workflow permissions: Read and write packages.

## Configuration

| File | Purpose |
|---|---|
| `.github/workflows/ci.yml` | Lint + test + Docker build + health |
| `.github/workflows/docker-publish.yml` | Tag-triggered publish to `ghcr.io/${{ github.repository }}` |
| `app/Dockerfile` | Non-root, `HEALTHCHECK` via `fetch` |
| `app/server.js` | `/health` returns `{status:ok, version: sha7}` |
| `scripts/healthcheck.sh` | `curl /health` gate |

Override image: edit `docker-publish.yml` `images:` or `app/Dockerfile` base.

## Deployment

CI runs automatically on `push`. To publish:

```bash
git tag v1.0.0 && git push origin v1.0.0
# or: Actions → Docker Publish → Run workflow
```

Pull:

```bash
docker pull ghcr.io/<your-org>/github-actions-cicd:latest
docker pull ghcr.io/<your-org>/github-actions-cicd:1.0.0
docker pull ghcr.io/<your-org>/github-actions-cicd:sha-<short>
```

## Testing

```bash
node --check app/server.js
node --test app/server.js   # or cd app && node --test
docker build -t app:ci ./app
bash scripts/healthcheck.sh http://localhost:3000/health
```

CI does the same plus ephemeral container probe.

## Monitoring / Logging

- Actions logs per job/step; Docker build provenance in GHCR package view
- Local: `docker logs <container>`, `curl /health`

## Security

- No secrets in repo (`.env`/`*.pem` ignored)
- `GITHUB_TOKEN` is ephemeral, scoped to `packages: write`
- Image `USER appuser` non-root, `HEALTHCHECK`
- For private images, GHCR requires `docker login ghcr.io -u <you> -p <PAT>` locally

## Cleanup

```bash
docker rm -f app-ci 2>/dev/null || true
docker rmi app:ci ghcr.io/your-org/github-actions-cicd:latest || true
# GHCR: Package → Settings → Delete versions
```

## Project Structure

```
github-actions-cicd/
├── README.md
├── .gitignore
├── .github/workflows/
│   ├── ci.yml
│   └── docker-publish.yml
├── app/
│   ├── Dockerfile
│   ├── package.json
│   └── server.js
├── scripts/healthcheck.sh
├── docs/
├── diagrams/
└── screenshots/
```

## Future Improvements

- Add `trivy`/`cosign` attestations, `gitleaks` secret scan, CodeQL
- Add `deploy` job (SSH or K8s) gated on `publish`
- Add Renovate/Dependabot for base image bumps
