# Architecture

## Overview
\\\
Internet -> Ingress (nginx, demo.local) -> Service :80 -> Deployment (2 replicas) -> Pod :3000
                        ConfigMap (PORT, APP_VERSION) + Secret (api-key) -> Pod env
                        HPA 2-6 on CPU 70% / mem 80%
\\\
Cluster: Kind/minikube/Docker Desktop/EKS/GKE/AKS + nginx Ingress Controller.

## Manifests
| File | Kind | Purpose |
|---|---|---|
| k8s/namespace.yaml | Namespace | demo-app isolation |
| k8s/configmap.yaml | ConfigMap | PORT, APP_VERSION, NODE_ENV |
| k8s/secret.yaml | Secret | api-key placeholder (base64 change-me) |
| k8s/deployment.yaml | Deployment | 2 replicas, RollingUpdate maxSurge1/maxUnavailable0, probes, resources, securityContext |
| k8s/service.yaml | Service | ClusterIP 80->3000 named port http |
| k8s/ingress.yaml | Ingress | host demo.local / -> demo-app:80 |
| k8s/hpa.yaml | HPA | min2 max6 CPU70 mem80 |

## Deployment details
- Probes: liveness /health (10s/15s), readiness /ready (5s/5s) httpGet port http.
- Resources: requests 100m/128Mi limits 300m/256Mi.
- Security: pod runAsNonRoot 10001 fsGroup 10001 seccomp RuntimeDefault; container allowPrivilegeEscalation false readOnlyRootFilesystem true drop ALL.
- Image: ghcr.io/your-org/kubernetes-demo-app:1.0.0 IfNotPresent (Kind loaded).

## Data plane
Ingress -> Service -> Deployment -> Pod Node.js :3000 with envFrom ConfigMap and Secret keyRef.

## Technology notes
- Deployment for declarative replicas + rolling updates.
- HPA for load-driven autoscaling (needs metrics-server).
- Ingress for host/path routing; alternative: Gateway API.
