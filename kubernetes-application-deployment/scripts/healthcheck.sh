#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-demo-app}"
SERVICE="${SERVICE:-demo-app}"
TIMEOUT="${TIMEOUT:-60}"

echo "[healthcheck] Port-forwarding svc/$SERVICE in $NAMESPACE for $TIMEOUT s"
kubectl port-forward "svc/$SERVICE" -n "$NAMESPACE" 8080:80 >/tmp/k8s-pf.log 2>&1 &
PF_PID=$!
sleep 3

cleanup() { kill "$PF_PID" 2>/dev/null || true; }
trap cleanup EXIT

for i in $(seq 1 "$TIMEOUT"); do
  if curl -fsS http://localhost:8080/health >/dev/null 2>&1; then
    echo "HEALTHY after ${i}s"
    curl -s http://localhost:8080/health
    echo
    exit 0
  fi
  sleep 1
done

echo "UNHEALTHY after $TIMEOUT s" >&2
cat /tmp/k8s-pf.log >&2 || true
exit 1
