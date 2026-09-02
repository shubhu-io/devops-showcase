# Architecture — kubernetes-application-deployment

## Cluster
Any CNCF-conformant cluster: Kind, minikube, Docker Desktop, or managed EKS/GKE/AKS with nginx Ingress Controller.

## Manifests
- `namespace.yaml` — `demo-app`
- `configmap.yaml` — `PORT`, `APP_VERSION`
- `secret.yaml` — placeholder `api-key` (base64)
- `deployment.yaml` — 2 replicas, `RollingUpdate`, probes, resources, `securityContext`
- `service.yaml` — ClusterIP `80->3000`
- `ingress.yaml` — `host: demo.local` → Service
- `hpa.yaml` — `min 2 max 6` on CPU 70% / mem 80%

## Data Plane
`Ingress → Service → Deployment → Pod (Node.js :3000)` with envFrom ConfigMap and Secret.

## Security
`runAsNonRoot 10001`, `readOnlyRootFilesystem`, `drop ALL`, `RuntimeDefault`.
