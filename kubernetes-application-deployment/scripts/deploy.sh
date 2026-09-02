#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="demo-app"
IMAGE="${IMAGE:-ghcr.io/your-org/kubernetes-demo-app:1.0.0}"

echo "==> Namespace"
kubectl apply -f k8s/namespace.yaml

echo "==> ConfigMap & Secret"
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml

echo "==> Deployment & Service (image: $IMAGE)"
# Allow overriding image via env
if [[ -n "${IMAGE}" ]]; then
  kubectl set image deployment/demo-app demo-app="$IMAGE" -n "$NAMESPACE" 2>/dev/null || true
fi
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

echo "==> Ingress & HPA"
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml

echo "==> Wait for rollout"
kubectl rollout status deployment/demo-app -n "$NAMESPACE" --timeout=120s

echo "==> Pods"
kubectl get pods -n "$NAMESPACE" -o wide

echo "Deploy complete. Try: kubectl port-forward svc/demo-app -n $NAMESPACE 8080:80 && curl http://localhost:8080/health"
