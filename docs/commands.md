# Commands

```bash
node --check app/server.js
cd app && node --test server.js
docker build -t app:ci ./app
docker run -d -p 3000:3000 --name app-ci app:ci && curl http://localhost:3000/health
bash scripts/healthcheck.sh http://localhost:3000/health
docker logs app-ci
docker rm -f app-ci
git tag v1.0.0 && git push origin v1.0.0
gh run list --limit 5
docker pull ghcr.io/<org>/github-actions-cicd:latest
```
