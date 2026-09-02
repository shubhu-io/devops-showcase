# Security

Security considerations for this GitHub + Jenkins + Docker setup, from credentials to the container runtime.

## 1. Credentials live in Jenkins, never in the Jenkinsfile

- The Jenkinsfile references credentials **by placeholder ID** (`github-creds`, `docker-registry-creds`) and reads them via `credentials('id')` when needed.
- Real secrets are stored in the **Jenkins Credentials store**, which encrypts them at rest with the controller's secret key.
- GitHub tokens: use a **Personal Access Token** with the narrowest scopes needed (`repo` for private repos), not your account password.
- **Never** hardcode a token, password, or API key in a Jenkinsfile, `.env`, or commit message. The `.env.example` uses placeholders only; the real `.env` is git-ignored.

## 2. Never hardcode secrets — anywhere

- `.gitignore` excludes `.env` and local state; the repo contains only `.env.example` placeholders.
- If a secret is accidentally committed, rotate it immediately (revoke the token) and scrub history — committing then "deleting" is not enough.
- Consider a secret manager for production: HashiCorp Vault, AWS Secrets Manager, or the Jenkins *Secret text* / *binding* plugins.

## 3. `/var/run/docker.sock` — the big risk

Mounting the host Docker socket into the Jenkins container is the **Docker-outside-of-Docker (DooD)** pattern.

- **What it gives you:** the pipeline can run `docker build`, `docker run`, `docker exec` without a nested daemon.
- **The risk:** `docker.sock` is an unauthenticated root-equivalent handle to the host daemon. Any code that runs inside the Jenkins container (a malicious pipeline, a compromised plugin, a build script) can `docker run -v /:/host ...`, i.e. gain **full root on the host**.
- **Mitigations (all weaker than not mounting the socket):**
  - Only run trusted pipelines and disable SCM-triggered builds for untrusted repos.
  - Keep the controller in a dedicated sandboxed VM in production.
  - Use `--read-only`, cap memory/CPU, and update plugins continuously.
- **Safer alternatives:**
  - **DinD (Docker-in-Docker):** a `docker:dind` sidecar service the controller talks to over `DOCKER_HOST`; builds still get containers, but host access is bounded to the dind daemon.
  - **Ephemeral build agents:** each build runs on a throwaway agent/VM; no persistent host socket.
  - **Rootless / podman socket activation** to avoid a privileged daemon.

## 4. Least privilege

- The app container runs as **non-root** `node` user (`USER node` in `app/Dockerfile`).
- The Jenkins controller itself runs as `jenkins` user; root is only used in the Dockerfile to install packages.
- Don't run the container with `privileged: true` unless you actually need kernel features (the compose file sets `privileged: false`).
- Don't bind additional host directories into Jenkins beyond the socket and config.

## 5. Secret scanning

- Run the **Security Check** stage (Trivy) on the app image; it also flags secret-like content in filesystems when pointed at the tree (`trivy fs .`).
- For repos, add GitHub secret scanning / Dependabot, or a tool like `gitleaks`/`trufflehog` in CI.
- In this pipeline, Trivy runs with `--exit-code 0` (report only). To enforce a minimum bar, switch to `--exit-code 1` for HIGH/CRITICAL findings — but be prepared to update base images.

## 6. Plugin and image updates

- Jenkins plugins are a primary attack surface (see the 2024 remote-code-execution class of Jenkins bugs). Subscribe to plugin updates and the Jenkins security advisory list.
- `jenkins/plugins.txt` pins the set used here; re-pull the `jenkins/jenkins:lts` base and rebuild to get fixes.
- Pin Trivy by tag (e.g. `aquasec/trivy:0.58.2`) instead of `latest` for reproducible scans.

## 7. Jenkins controller hardening

- Change the JCasC default admin password (`admin`/`change-me-admin-password`) on first login.
- Set `allowsSignup: false` (already done in JCasC) and restrict anonymous read.
- Enable CSRF protection (default) and use API tokens instead of raw passwords in scripts.
- Enable Jenkins **Audit Trail** / Job log retention; keep `buildDiscarder` so old logs (which can contain paths/user names) are pruned.
- Back up `jenkins_home` (the compose volume) — it holds credentials, keys, and job config.

## Checklist before going further

- [ ] Admin password changed from placeholder
- [ ] GitHub token uses minimal scopes; nothing secret in the repo
- [ ] Docker socket only exposed where needed; controller in sandbox
- [ ] Trivy gating decided (`--exit-code 0` vs `1`)
- [ ] Plugins pinned + update subscription configured
- [ ] `jenkins_home` backup plan exists
