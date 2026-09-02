# Architecture Decision Records (ADRs)

Each record: **Decision / Why / Alternatives / Why not / Consequences.**

---

## ADR-001: Deploy to EC2 (VM) instead of ECS or Lambda

- **Decision:** Run the app as a Docker container on a single AWS EC2 Ubuntu instance
  managed manually (SSH), with Nginx in front.
- **Why:** We need a real, inspectable Linux host to learn Jenkins + SSH + Docker +
  Nginx hands-on. EC2 gives full control over everything with a tiny free-tier cost.
- **Alternatives:** AWS ECS/Fargate, Elastic Beanstalk, Lambda.
- **Why not:** ECS/Fargate hides the host — no SSH, no manual Docker, less learning.
  Lambda is ephemeral and unsuitable for a long-running web server with a Docker
  image workflow. Beanstalk hides the underlying VM almost entirely.
- **Consequences:** We own patching, security-group rules, and Nginx config; scaling
  to multiple hosts requires extra work (ADR-007-ish future improvements).

---

## ADR-002: Build the image on the Jenkins agent with the host's Docker socket, not DinD

- **Decision:** The Jenkins pipeline runs `docker build` directly (host Docker
  socket); no Docker-in-Docker (`docker:dind` sidecar) is used.
- **Why:** Simplest setup for a learning pipeline — one Docker daemon, images land
  in the local store ready to `docker save` and pipe to EC2. No nested-containers
  overhead or volume mounts.
- **Alternatives:** Docker-in-Docker (DinD) or a separate build container
  (e.g. `docker:latest` agent).
- **Why not:** DinD adds complexity and performance overhead and can corrupt the
  build cache; the isolation benefits only matter when running untrusted pipelines
  on shared agents (a future concern, not a current one).
- **Consequences:** The Jenkins user must be in the `docker` group (access to
  `/var/run/docker.sock` is root-equivalent). This is acceptable on our own agent
  but documented as a security trade-off.

---

## ADR-003: Deploy by SSH + docker save/load transfer instead of registry pull

- **Decision:** Default deploy path: `docker save node-app:<N> | ssh ubuntu@IP 'docker load'`,
  then `docker run` remotely. A registry mode (`USE_REGISTRY=true`) is supported
  but not the default.
- **Why:** Zero external services — no Docker Hub/ECR account, no `docker login`,
  no credentials to manage. Works offline and teaches exactly what a registry
  would otherwise abstract. Fully scriptable with `sshagent`.
- **Alternatives:** Push to Docker Hub, push to ECR, or `scp` the tar file.
- **Why not:** Every registry option needs credentials + IAM setup (ECR) or a public
  namespace (Docker Hub) and adds moving parts. For a single-host learning setup
  they buy little. Image transfer is slower for very large images — the documented
  trigger to switch to registry mode.
- **Consequences:** Transfer time grows with image size; there's no image
  inventory/audit trail on a registry; moving to multi-host later means switching
  to registry pull (ADR-007).

---

## ADR-004: Nginx reverse proxy in front of the app container

- **Decision:** Nginx runs on the EC2 host, listens on port 80, and `proxy_pass`es
  to the app container bound on `127.0.0.1:3000`.
- **Why:** A public web app benefits from a battle-tested web server at the edge:
  a single entry point, and a clean seam where TLS, caching, rate limiting, and
  static assets can be added without touching app code.
- **Alternatives:** Publish the container directly on port 80; use HAProxy/Caddy/
  Traefik; use an AWS ALB.
- **Why not:** Publishing the container directly exposes the app runtime to the
  internet and couples app changes to networking changes. Traefik/ALB are overkill
  for a single host and add a new layer to learn.
- **Consequences:** One extra hop (Nginx → container), one more service to keep
  running, and a config file (`nginx/app-proxy.conf`) that must stay in sync with
  the deploy layout. Nginx is reliable enough that this cost is minimal.

---

## ADR-005: Run Jenkins on a separate host, not on the EC2 deploy host

- **Decision:** Jenkins runs independently (locally or its own machine/container),
  NOT on the same EC2 instance that runs the app.
- **Why:** Separation of duties — a broken deploy (or a public internet issue) can't
  take down the CI server, and a compromised Jenkins can't be reached over the app's
  public surface. The pipeline needs SSH out to EC2 anyway, which works from
  anywhere.
- **Alternatives:** Install Jenkins ON the app EC2 host; run Jenkins in Docker on
  the host.
- **Why not:** Co-locating means one instance failing kills both CI and the app;
  port 8080 must be exposed (more attack surface); host upgrades affect both
  workloads. Running Jenkins-in-Docker on the same host keeps the coupling.
- **Consequences:** Jenkins needs its own install/upkeep; the SSH key and `scp`
  paths must be reachable from wherever Jenkins runs. Acceptable and clearly
  documented in [setup.md](setup.md).

---

## ADR-006: Security group with least-privilege ingress (22 from my IP, 80 public)

- **Decision:** Inbound rules: TCP 22 only from `YOUR_IP/32`; TCP 80 from
  `0.0.0.0/0`; everything else denied by default. `ufw` on the host is defense-in-depth.
- **Why:** The instance must be publicly reachable on HTTP but administratively
  reachable only by us. Narrowing the SSH source drastically reduces brute-force
  and scanning exposure.
- **Alternatives:** Open 22 to `0.0.0.0/0` (common but risky), rely on host firewall
  only, put the instance in a private subnet with a bastion.
- **Why not:** Opening 22 to everyone invites credential-stuffing even with key auth.
  A private subnet + bastion is the strongest option but adds a second instance and
  more routing complexity than a learning project needs.
- **Consequences:** If your home IP changes, SSH breaks until you update the SG rule
  (a one-command fix, documented in troubleshooting). The trade-off is worth it.
