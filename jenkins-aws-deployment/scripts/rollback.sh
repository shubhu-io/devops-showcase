#!/usr/bin/env bash
# rollback.sh
# Purpose: runs ON the EC2 host. Stops the currently running container and
#          re-runs a PREVIOUS image tag, then health-checks it.
#
# Usage:
#   TAG=node-app:81 CONTAINER_NAME=node-app APP_PORT=3000 bash /opt/devops/rollback.sh
#   TAG=81 CONTAINER_NAME=node-app APP_PORT=3000 bash /opt/devops/rollback.sh
set -euo pipefail

: "${TAG:?TAG environment variable required (full image:tag or just tag)}"
: "${CONTAINER_NAME:=node-app}"
: "${APP_PORT:=3000}"
HOST_IP="127.0.0.1"
HOST_PORT="${APP_PORT}"
HEALTH_URL="http://127.0.0.1:${APP_PORT}/health"
RETRIES=15
RETRY_SLEEP=3

# If TAG is just a number/tag, prefix it with the image name.
case "${TAG}" in
  */*|*:*) PREV_IMAGE="${TAG}" ;;      # already "image:tag" or "registry/repo:tag"
  *)       PREV_IMAGE="node-app:${TAG}" ;;
esac

log() { echo "[rollback] $*"; }

log "Rollback requested: restoring ${PREV_IMAGE}"

if ! docker image inspect "${PREV_IMAGE}" >/dev/null 2>&1; then
  log "Image ${PREV_IMAGE} not present locally - trying to pull..."
  docker pull "${PREV_IMAGE}" || { log "FATAL: cannot obtain image ${PREV_IMAGE}"; exit 1; }
fi

# Stop and remove the bad container.
if docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  log "Stopping current container ${CONTAINER_NAME}..."
  docker stop "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  docker rm "${CONTAINER_NAME}" >/dev/null 2>&1 || true
fi

log "Starting ${CONTAINER_NAME} from ${PREV_IMAGE} on ${HOST_IP}:${HOST_PORT} -> ${APP_PORT}"
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart unless-stopped \
  -p "${HOST_IP}:${HOST_PORT}:${APP_PORT}" \
  -e BUILD_VERSION="${PREV_IMAGE##*:}" \
  -e PORT="${APP_PORT}" \
  "${PREV_IMAGE}"

healthy=""
for i in $(seq 1 "${RETRIES}"); do
  if curl -fsS "${HEALTH_URL}" >/dev/null 2>&1; then
    healthy="yes"
    log "Health check passed on attempt ${i}."
    break
  fi
  sleep "${RETRY_SLEEP}"
done

if [ -n "${healthy}" ]; then
  log "ROLLBACK OK: now running ${PREV_IMAGE}."
  exit 0
else
  log "FAIL: rolled-back container is also unhealthy. Investigate: docker logs ${CONTAINER_NAME}"
  docker logs --tail 50 "${CONTAINER_NAME}" 2>&1 || true
  exit 1
fi
