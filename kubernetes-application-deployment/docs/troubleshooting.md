# Troubleshooting

## Pod CrashLoopBackOff
`kubectl logs -f deployment/demo-app -n demo-app` + `kubectl describe pod`

## ImagePullBackOff
`kind load docker-image` for Kind, or `docker push` + correct `image:` in `deployment.yaml`

## Ingress 404
Check `ingressClassName: nginx` and controller installed, `host: demo.local` with `/etc/hosts` entry.

## HPA not scaling
Requires metrics-server: `kubectl top pods -n demo-app` should return metrics.
