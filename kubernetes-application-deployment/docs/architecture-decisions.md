# Architecture Decisions

- Kind for local parity with cloud K8s; no cloud spend for dev.
- Deployment RollingUpdate maxSurge1 maxUnavailable0 for zero-downtime.
- ClusterIP + Ingress vs LoadBalancer: Ingress is portable and host/path aware.
- ConfigMap + Secret externalize config; Deployment envFrom/env keyRef.
- HPA v2 CPU/memory vs KEDA for event-driven scaling.
- imagePullPolicy IfNotPresent for Kind loaded images; cloud would use Always + imagePullSecrets.
