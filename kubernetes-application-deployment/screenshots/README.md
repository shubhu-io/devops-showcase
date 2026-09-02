# Screenshots — kubernetes-application-deployment

Capture, do not fabricate:

1. `kubectl get pods -n demo-app`
2. `kubectl get svc,ingress,hpa -n demo-app`
3. `curl http://localhost:8080/health` after port-forward
4. `kubectl top pods -n demo-app` (if metrics-server)
5. `kubectl logs deployment/demo-app -n demo-app --tail=20`

Store as `screenshots/*.png` (gitignored by default, README explains capture).
