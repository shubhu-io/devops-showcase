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

## Deploy Your Own App (3 changes)

**1. Use your GitHub repo:**
```bash
# fork https://github.com/shubhu-io/kubernetes-application-deployment
git clone https://github.com/<YOUR_USERNAME>/kubernetes-application-deployment.git
cd kubernetes-application-deployment
git remote set-url origin https://github.com/<YOUR_USERNAME>/kubernetes-application-deployment.git
```

**2. Change the container image (2 places):**
```bash
# a) Build & push your app
docker build -t ghcr.io/<YOUR_USERNAME>/my-app:1.0.0 ./app
docker push ghcr.io/<YOUR_USERNAME>/my-app:1.0.0
# b) Update manifest
nano k8s/deployment.yaml
# image: ghcr.io/your-org/kubernetes-demo-app:1.0.0 -> ghcr.io/<YOUR_USERNAME>/my-app:1.0.0
# also update ConfigMap APP_VERSION if needed
nano k8s/configmap.yaml
```

**3. Deploy:** `bash scripts/deploy.sh` (or `kubectl apply -f k8s/`)

