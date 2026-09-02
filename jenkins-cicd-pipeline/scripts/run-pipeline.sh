#!/usr/bin/env bash
# ============================================================================
# Local demo launcher for the Jenkins + Docker CI/CD project.
#
#   bash scripts/run-pipeline.sh
#
# What it does:
#   1. Pre-flight checks (docker, docker compose).
#   2. Builds and starts the Jenkins controller (jenkins/docker-compose.yml).
#   3. Prints the initial admin password retrieval command.
#
# NOTE: Assumes a Unix shell (Git Bash / WSL / macOS / Linux). On Windows
# PowerShell, use the equivalent commands in docs/commands.md instead.
# ============================================================================
set -euo pipefail

COMPOSE_FILE="jenkins/docker-compose.yml"
CONTAINER="jenkins"

log()  { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33m==>\033[0m %s\n' "$*"; }

log "Pre-flight checks"

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker not found in PATH. Install Docker first (docs/setup.md)."
  exit 1
fi
docker info >/dev/null 2>&1 || { echo "ERROR: docker daemon is not running."; exit 1; }

if ! docker compose version >/dev/null 2>&1; then
  echo "ERROR: docker compose (v2) is required."
  exit 1
fi

log "Building and starting the Jenkins controller"
docker compose -f "$COMPOSE_FILE" up -d --build

log "Waiting for Jenkins to become reachable (up to 90s)"
for i in $(seq 1 30); do
  if docker exec "$CONTAINER" curl -sf http://localhost:8080/login >/dev/null 2>&1; then
    echo "Jenkins is up after $((i * 3))s."
    break
  fi
  sleep 3
done

log "Jenkins UI:      http://localhost:8080"
warn "Initial admin password (one-time, shown on first boot):"
echo
echo "  docker exec $CONTAINER cat /var/jenkins_home/secrets/initialAdminPassword"
echo
warn "If the initialAdminPassword file is missing (already unlocked), log in with"
echo "the admin user defined in jenkins/config-as-code/jenkins.yaml instead."
echo
log "Next: create a Pipeline job pointing at your git repo with script path 'Jenkinsfile' (docs/setup.md)."
