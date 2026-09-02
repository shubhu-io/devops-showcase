#!/usr/bin/env bash
# End-to-end demo: build, start, wait, probe, inspect, tear down.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> 1. Validate compose file"
docker compose config >/dev/null

echo "==> 2. Build the app image (multi-stage)"
docker compose build app

echo "==> 3. Start the full stack"
docker compose up -d --build

echo "==> 4. Wait for health"
for i in $(seq 1 30); do
  if curl -fsS --max-time 2 http://localhost/health >/dev/null 2>&1; then
    echo "healthy after ${i}s"
    break
  fi
  sleep 1
  [ "$i" = "30" ] && { echo "health check timed out" >&2; docker compose logs; exit 1; }
done

echo "==> 5. Probe endpoints"
echo "--- GET /"
curl -sS http://localhost/ | head -n 20

echo
echo "--- GET /health"
curl -sS http://localhost/health

echo
echo "--- GET /api/message"
curl -sS http://localhost/api/message

echo
echo "==> 6. docker ps"
docker ps

echo "==> 7. docker images"
docker images | grep -E 'dockerized-app|nginx|postgres' || docker images

echo "==> 8. docker network ls"
docker network ls | grep appnet

echo "==> 9. logs (app)"
docker compose logs --tail=30 app

echo "==> 10. Tear down (keep pgdata volume)"
docker compose down
