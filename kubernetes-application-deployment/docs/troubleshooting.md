# Troubleshooting

- ImagePullBackOff: \kind load docker-image ...\ or push to GHCR and set imagePullSecrets.
- Pods CrashLoopBackOff: \kubectl logs -f deployment/demo-app -n demo-app\, check \eadOnlyRootFilesystem\ and writable /tmp (emptyDir if needed).
- Liveness/readiness failing: \kubectl describe pod -l app=demo-app -n demo-app | grep -A5 Probe\, verify app listens on 3000.
- HPA not scaling: install metrics-server (\kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml\).
- Ingress 404: check \kubectl get ingress -n demo-app\, add \127.0.0.1 demo.local\ to /etc/hosts, \curl -H "Host: demo.local" http://localhost/\.
- Namespace stuck terminating: \kubectl delete namespace demo-app --force --grace-period=0\ (last resort).
