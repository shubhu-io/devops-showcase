# Steps — kubernetes-application-deployment

Copy-paste execution.

## Prerequisites
- Docker, kubectl, Kind or minikube

## Clone
```bash
git clone https://github.com/shubhu-io/kubernetes-application-deployment.git
cd kubernetes-application-deployment
```

## Run
```bash
kind create cluster --name demo
docker build -t ghcr.io/your-org/kubernetes-demo-app:1.0.0 ./app
kind load docker-image ghcr.io/your-org/kubernetes-demo-app:1.0.0 --name demo
bash scripts/deploy.sh
kubectl get pods -n demo-app
kubectl port-forward svc/demo-app -n demo-app 8080:80 &
curl http://localhost:8080/health
bash scripts/healthcheck.sh
```

## Cleanup
```bash
kubectl delete -f k8s/
kubectl delete namespace demo-app
kind delete cluster --name demo
```
