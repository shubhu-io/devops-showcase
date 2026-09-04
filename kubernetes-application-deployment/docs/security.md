# Security

- Secret placeholder only (api-key change-me base64); real secrets via SealedSecrets/ExternalSecrets/Vault, never committed.
- kubeconfig gitignored, .kube/ ignored.
- Pod securityContext runAsNonRoot 10001, fsGroup 10001, seccomp RuntimeDefault.
- Container allowPrivilegeEscalation false, readOnlyRootFilesystem true, capabilities drop ALL.
- Image USER appuser non-root, HEALTHCHECK via fetch.
- Namespace isolation demo-app, HPA limits prevent noisy-neighbor.
- Future: NetworkPolicy default deny, PodSecurityStandards restricted, RBAC least privilege.
