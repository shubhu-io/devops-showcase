# Setup — kubernetes-application-deployment

## Prerequisites
- Docker, kubectl, cluster (Kind/minikube/cloud) + nginx Ingress Controller

## Steps
```bash
git clone https://github.com/shubhu-io/kubernetes-application-deployment.git
cd kubernetes-application-deployment
kind create cluster --name demo
docker build -t ghcr.io/your-org/kubernetes-demo-app:1.0.0 ./app
kind load docker-image ghcr.io/your-org/kubernetes-demo-app:1.0.0 --name demo
bash scripts/deploy.sh
kubectl port-forward svc/demo-app -n demo-app 8080:80 &
curl http://localhost:8080/health
```
