#!/usr/bin/env bash
# deploy.sh
# Purpose: runs ON the EC2 host. Loads/pulls the app image, stops the old
#          container, starts the new one on port 80 -> 3000 behind Nginx,
#          runs a health-check loop, and can trigger a rollback on failure.
#
# Usage (called by Jenkins over SSH):
#   IMAGE=node-app:83             \
#   CONTAINER_NAME=node-app       \
#   APP_PORT=3000                 \
#   BUILD_VERSION=83              \
#   bash /opt/devops/deploy.sh
#
# The image can arrive in one of two ways:
#   1. Registry  -> script pulls IMAGE (typical with ECR/Docker Hub)
#   2. SCP/save  -> Jenkins does `docker save | ssh ... docker load`, the
#      image already exists locally, so pull becomes a no-op fallback.
set -euo pipefail

: "${IMAGE:?IMAGE environment variable required (e.g. node-app:83)}"
: "${CONTAINER_NAME:=node-app}"
: "${APP_PORT:=3000}"
: "${BUILD_VERSION:=${IMAGE##*:}}"
# Bind container to loopback so only Nginx (port 80) is exposed publicly
HOST_IP="127.0.0.1"
HOST_PORT="${APP_PORT}"
HEALTH_URL="http://127.0.0.1:${APP_PORT}/health"
RETRIES=15
RETRY_SLEEP=3

log() { echo "[deploy] $*"; }

# --- 0. Ensure Docker is running ----------------------------------------------
if ! docker info >/dev/null 2>&1; then
  log "Docker daemon is not running - attempting to start it..."
  sudo systemctl start docker || { log "FATAL: could not start docker"; exit 1; }
fi

# --- 1. Get the image ----------------------------------------------------------
if docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  log "Image ${IMAGE} already present locally."
else
  log "Image ${IMAGE} not local - attempting to pull (registry mode) or waiting for docker load..."
  docker pull "${IMAGE}" || log "Pull failed; if image is transferred via ssh docker load, it will appear shortly."
  # Give an scp/docker load in flight a moment to finish.
  sleep 3
  if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
    log "FATAL: image ${IMAGE} is not available locally and could not be pulled."
    exit 1
  fi
fi

# --- 2. Stop and remove the OLD container --------------------------------------
if docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  log "Stopping old container ${CONTAINER_NAME}..."
  docker stop "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  docker rm "${CONTAINER_NAME}" >/dev/null 2>&1 || true
fi

# --- 3. Run the NEW container ---------------------------------------------------
log "Starting ${CONTAINER_NAME} from image ${IMAGE} on ${HOST_IP}:${HOST_PORT} -> ${APP_PORT}"
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart unless-stopped \
  -p "${HOST_IP}:${HOST_PORT}:${APP_PORT}" \
  -e BUILD_VERSION="${BUILD_VERSION}" \
  -e PORT="${APP_PORT}" \
  "${IMAGE}"

# --- 4. Health check loop -------------------------------------------------------
log "Waiting for ${HEALTH_URL} to respond (up to $((RETRIES * RETRY_SLEEP))s)..."
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
  log "DEPLOY OK: container ${CONTAINER_NAME} (${IMAGE}) is healthy."
  exit 0
fi

# --- 5. Rollback hook on failure ------------------------------------------------
log "FATAL: new container did not become healthy. Triggering rollback hook."
log "Running: /opt/devops/rollback.sh"
if [ -f /opt/devops/rollback.sh ]; then
  # Delegate to rollback if it knows a previous tag; otherwise just clean up.
  PREV_TAG="${PREV_IMAGE_TAG:-}"
  if [ -n "${PREV_TAG}" ]; then
    TAG="${PREV_TAG}" /opt/devops/rollback.sh
  else
    log "No PREV_IMAGE_TAG provided - leaving failed container for manual inspection."
    docker logs --tail 50 "${CONTAINER_NAME}" 2>&1 || true
  fi
fi
exit 1
