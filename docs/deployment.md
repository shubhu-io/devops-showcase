# Deployment

CI auto on push to main. Publish on tag:

```bash
git tag v1.0.0 && git push origin v1.0.0
# or Actions -> Docker Publish -> Run workflow
docker pull ghcr.io/<your-org>/github-actions-cicd:latest
docker run -d -p 3000:3000 ghcr.io/<your-org>/github-actions-cicd:latest
curl http://localhost:3000/health
```

GHCR provenance visible in package view. Re-run publish via workflow_dispatch.
