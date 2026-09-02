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

## Deploy Your Own App (3 changes)

**1. Use your GitHub repo (Actions auto-uses your repo name):**
```bash
# fork https://github.com/shubhu-io/github-actions-cicd
git clone https://github.com/<YOUR_USERNAME>/github-actions-cicd.git
cd github-actions-cicd
git remote set-url origin https://github.com/<YOUR_USERNAME>/github-actions-cicd.git
git push -u origin master
# enable Actions: Settings -> Actions -> General -> Allow all actions
# GHCR uses ghcr.io/${{ github.repository }} so no manual image rename needed
```

**2. Replace the app:**
```bash
nano app/server.js
# keep /health returning {status:"ok"} or update scripts/healthcheck.sh
```

**3. Publish:** `git tag v1.0.0 && git push origin v1.0.0` → Actions → Docker Publish → `ghcr.io/<YOUR_USERNAME>/github-actions-cicd:1.0.0`

