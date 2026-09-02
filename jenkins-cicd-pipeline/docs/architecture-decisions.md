# Architecture Decisions (ADRs)

Lightweight Architecture Decision Records in the **Decision / Why / Alternatives / Why not / Consequences** format.

---

## ADR-001: Use Jenkins instead of GitHub Actions

- **Decision:** Jenkins as the CI/CD orchestrator, triggered from GitHub via webhook.
- **Why:** The project theme is explicitly "GitHub + Git + Jenkins + Docker". Jenkins is the industry classic for learning how CI servers work, is self-hosted and free, has a mature plugin ecosystem (git, docker-workflow, blueocean, JCasC), and keeps pipeline config visible in a dedicated, extensible tool rather than platform-tied YAML.
- **Alternatives:** GitHub Actions, GitLab CI, CircleCI, Azure DevOps, TeamCity.
- **Why not:** GitHub Actions is simpler to start (runners are hosted, workflows live next to the code) but was not chosen because the goal is to understand a **standalone controller + agents** model, job configuration, credentials store, and manual pipeline wiring — concepts Actions hides.
- **Consequences:** We must run and maintain a Jenkins server (here: a Docker container), patch/update plugins, and manage the controller's storage. In exchange we get deep visibility into the CI system and the exact skills the project theme demands.

---

## ADR-002: Run Jenkins in Docker with a host Docker socket mount (DooD) instead of Docker-in-Docker (DinD)

- **Decision:** Jenkins controller runs in a container; it controls the host Docker daemon through `/var/run/docker.sock` (Docker-outside-of-Docker).
- **Why:** DooD is simple and fast — no nested daemon, no privileged mode, no extra image. Builds, runs, and health checks just work against the host daemon, and containers spawned are normal host containers.
- **Alternatives:** (a) DinD: a `docker:dind` sidecar container that Jenkins talks to via `DOCKER_HOST=tcp://dind:2375`; (b) remote/dynamic agents that each provision their own Docker; (c) Podman rootless socket.
- **Why not:** DinD adds a privileged daemon, extra complexity, and its own nested-storage quirks. Remote agents are overkill for a single-machine demo. Podman is less documented for this exact Jenkins setup.
- **Consequences:** Mounting `docker.sock` is **root-equivalent on the host** (see `docs/security.md`). This is acceptable only for a local/sandboxed demo. For production, switch to DinD on a dedicated VM or ephemeral build agents. The `jenkins/Dockerfile` installs only the Docker **CLI** (no daemon), and the compose file documents the trade-off.

---

## ADR-003: Declarative (not Scripted) Pipeline

- **Decision:** The `Jenkinsfile` uses the **declarative** `pipeline { }` syntax.
- **Why:** Declarative provides a clear stage skeleton (`stages`), built-in `options`, `environment`, `agent`, and `post` success/failure blocks. It is more readable for reviewers and beginners, has a stricter structure that catches mistakes at parse time, and plays nicely with Blue Ocean.
- **Alternatives:** Scripted pipeline (`node { stage('x') { ... } }`), a freestyle job, or a shared-library-driven hybrid.
- **Why not:** Scripted is more flexible (full Groovy) but encourages complex logic inside the file; freestyle jobs don't version-control the build definition.
- **Consequences:** Complex conditional flows must be wrapped in `script { }` blocks (the Trivy guard and cleanup do this). We keep per-stage shell logic small so the file stays readable.

---

## ADR-004: Include Trivy in the pipeline as a report-only security gate

- **Decision:** A **Security Check** stage runs Trivy against the built image, defaulting to `--exit-code 0` (reports findings, never blocks). The Jenkinsfile guards it so a missing Trivy binary/image degrades to a SKIP notice rather than a red build.
- **Why:** Container scanning is cheap to add, catches known CVEs in base images, and demonstrates a real "shift-left" security step without breaking the demo on machines without Trivy.
- **Alternatives:** Snyk/Docker Scout (account + network dependency), Grype, or no scanning at all.
- **Why not:** Third-party SaaS scanners add accounts and secrets; no scanning leaves the image blindly shipped.
- **Consequences:** With `--exit-code 0` a vulnerable image can still pass — the switch to `--exit-code 1` for HIGH/CRITICAL is the production hardening documented in `docs/security.md`. We chose graceful degradation so first-time setup isn't blocked by a missing tool.

---

## ADR-005: Containerize the app with Docker for build and run

- **Decision:** The Node app is packaged with `app/Dockerfile` (from `node:24-alpine`, non-root `node` user, HEALTHCHECK) and deployed by `docker build` + `docker run` stages.
- **Why:** Docker gives a reproducible artifact (image) that runs identically in CI and anywhere else; the pipeline's run/health stages need a real running artifact, which Docker provides trivially. A zero-dependency Node app is the smallest possible thing to containerize.
- **Alternatives:** Build a binary/tarball artifact and run on bare metal; use a PaaS (Heroku, Render); use an orchestrator (Kubernetes).
- **Why not:** Bare-metal artifact drops lose environment reproducibility; PaaS hides the container mechanics we want to demonstrate; Kubernetes is far too heavy for a single-node demo.
- **Consequences:** Every build is an immutable `hello-app:<BUILD_NUMBER>` image; rolling back is re-running the pipeline on the old commit (see `docs/deployment.md`). The trade-off is image size/build time, both trivial for this app.
