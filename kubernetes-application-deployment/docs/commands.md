# Commands

```bash
kind create cluster --name demo
docker build -t ghcr.io/your-org/kubernetes-demo-app:1.0.0 ./app
kind load docker-image ghcr.io/your-org/kubernetes-demo-app:1.0.0 --name demo
bash scripts/deploy.sh
kubectl get pods,svc,ingress,hpa -n demo-app
kubectl rollout status deployment/demo-app -n demo-app
kubectl port-forward svc/demo-app -n demo-app 8080:80 &
curl http://localhost:8080/health
bash scripts/healthcheck.sh
kubectl logs -f deployment/demo-app -n demo-app
kubectl delete -f k8s/ --ignore-not-found
kind delete cluster --name demo
```
