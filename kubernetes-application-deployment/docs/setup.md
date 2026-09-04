# Setup

## Prerequisites
- Docker, kubectl v1.28+, cluster (Kind/minikube/Docker Desktop/EKS).

## Create cluster (Kind)
```bash
kind create cluster --name demo
kubectl cluster-info --context kind-demo
```

## Build & load image
```bash
docker build -t ghcr.io/your-org/kubernetes-demo-app:1.0.0 ./app
kind load docker-image ghcr.io/your-org/kubernetes-demo-app:1.0.0 --name demo
# for cloud: docker push ghcr.io/your-org/kubernetes-demo-app:1.0.0
```

## Ingress controller (Kind)
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s
```

## Deploy
```bash
bash scripts/deploy.sh
# or: kubectl apply -f k8s/
kubectl get pods,svc,ingress,hpa -n demo-app
```
