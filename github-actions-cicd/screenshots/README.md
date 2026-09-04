# Screenshots

Capture:

- Actions -> CI run green (lint-test + docker-build)
- Actions -> Docker Publish run with GHCR tags
- GHCR package view showing sha/semver/latest
- Local curl /health 200

`ash
gh run view <id>
curl http://localhost:3000/health
`
Store images as screenshots/*.png (ignored except README, add manually if needed).
