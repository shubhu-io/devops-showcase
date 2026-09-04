# Troubleshooting

- CI fails node --test: run locally cd app && node --test server.js (Node 20+).
- docker build fails: check pp/Dockerfile COPY paths, 
ode --check server.js.
- curl /health 404 or unhealthy: docker logs app-ci, docker ps, retry ash scripts/healthcheck.sh.
- GHCR 401: check repo Settings -> Actions -> permissions packages:write, GITHUB_TOKEN scope.
- Multi-arch build slow: Buildx gha cache enabled; first run warms.
- Path bug fixed: ci.yml working-directory app uses server.js not app/server.js.
