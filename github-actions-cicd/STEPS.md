# Steps — github-actions-cicd

Copy-paste execution.

## Prerequisites
- Docker, Node 18+, GitHub repo with Actions enabled

## Clone
```bash
git clone https://github.com/shubhu-io/github-actions-cicd.git
cd github-actions-cicd
```

## Run Locally
```bash
node --check app/server.js
docker build -t app:ci ./app
docker run -d -p 3000:3000 app:ci
bash scripts/healthcheck.sh
docker rm -f $(docker ps -q --filter ancestor=app:ci)
```

## Run via GitHub Actions
```bash
git push origin main                # triggers ci.yml
git tag v1.0.0 && git push origin v1.0.0  # triggers docker-publish.yml -> GHCR
```

## Cleanup
```bash
docker rmi app:ci
```
