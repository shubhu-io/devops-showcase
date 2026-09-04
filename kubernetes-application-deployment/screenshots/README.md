# Screenshots

Capture:
- kubectl get pods,svc,ingress,hpa -n demo-app
- kubectl port-forward + curl /health 200
- kubectl describe pod probes
- kind cluster-info

```bash
kubectl get pods -n demo-app
kubectl port-forward svc/demo-app -n demo-app 8080:80 &
curl http://localhost:8080/health
kubectl describe pod -l app=demo-app -n demo-app | grep -A5 Probe
```
Store as screenshots/*.png (gitignored by root .gitignore; keep README).
