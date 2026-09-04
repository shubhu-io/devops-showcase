# Architecture

## Overview
`
git push -> Actions: ci.yml (lint -> test -> docker build -> health) -> Docker Publish (buildx -> GHCR)
git tag v1.0.0 -> docker-publish.yml (metadata -> login GHCR -> buildx push -> sha/semver/latest)
`

Local: docker build -t app:ci ./app && bash scripts/healthcheck.sh.

## GH Components

### ci.yml (push/PR to main)
- checkout -> setup-node -> node --check -> node --test -> bash -n -> docker build -> docker run + curl /health

### docker-publish.yml (tags v*.*.* / manual)
- checkout -> setup-buildx -> login GHCR (GITHUB_TOKEN) -> metadata-action (semver/sha/latest) -> build-push (amd64/arm64, gha cache)

### GHCR
- Images: ghcr.io/github.repository with tags version/sha/latest, ephemeral GITHUB_TOKEN OIDC.

### App
- Node zero-deps, GET / and /health, USER appuser, HEALTHCHECK fetch /health.
