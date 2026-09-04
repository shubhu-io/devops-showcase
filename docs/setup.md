# Setup

## Local
```bash
git clone <this-repo> && cd github-actions-cicd
docker build -t app:ci ./app
docker run -d -p 3000:3000 app:ci
curl http://localhost:3000/health
node --check app/server.js
node --test app/server.js
bash scripts/healthcheck.sh
```

## GitHub
1. Push to GitHub, enable Actions.
2. Settings -> Actions -> General -> Workflow permissions: Read and write packages.
3. Push to main triggers ci.yml; tag v1.0.0 triggers publish.
```bash
git tag v1.0.0 && git push origin v1.0.0
# verify: gh run list, GHCR package view
```
