# Architecture

> Pipeline: **Developer → GitHub → Jenkins → Docker build → Test → Security check → Docker run → Health check**

```
┌──────────┐  git push   ┌────────┐   webhook   ┌───────────┐  docker CLI  ┌────────────┐
│ Developer├────────────►│ GitHub ├────────────►│  Jenkins  ├─────────────►│ Docker Host│
└──────────┘             └────────┘             └───────────┘              └────────────┘
                                                    │                             │
                                                    │ build/test/scan             │ build & run
                                                    ▼                             ▼
                                                 Jenkinsfile              hello-app container
                                                                          (port 3000 → 809N)
```

## Components

### 1. Git / GitHub
The remote **source of truth**. The developer pushes commits to a branch. GitHub fires a **webhook** (or Jenkins polls) so Jenkins knows a new commit exists. Every build is tied to a specific commit (`GIT_COMMIT`), which makes the pipeline reproducible and auditable.

### 2. Jenkins
The **CI/CD orchestrator**. It watches the repo, checks out the code into a workspace, and runs the **Jenkinsfile** (declarative pipeline) stage by stage: Checkout → Build → Test → Security → Docker build → Docker run → Health check → Cleanup. It runs inside its own Docker container (`jenkins/` folder) with the Docker CLI installed.

### 3. Docker
Two roles:
- **Build**: the app is baked into a reproducible image (`hello-app:<build-number>`).
- **Run**: the image is launched as a container with a unique name and host port per build, so multiple builds never clash.

Jenkins talks to the host Docker daemon through the mounted `/var/run/docker.sock` (Docker-outside-of-Docker). See [security.md](security.md) for the trade-off.

### 4. Docker Compose
Declaratively defines the Jenkins controller service: image build, ports `8080`/`50000`, env vars, the `jenkins_home` volume and the `docker.sock` + JCasC mounts. One command — `docker compose up -d` — starts the whole controller.

### 5. Trivy (aquasec)
A vulnerability scanner run in the **Security Check** stage. It scans the built image for known CVEs. In this demo it runs with `--exit-code 0` so it reports findings without blocking the build; a real setup flips it to `--exit-code 1` for HIGH/CRITICAL findings to fail the build.

### 6. Bash
Used for the local demo helpers (`scripts/run-pipeline.sh`, `scripts/healthcheck.sh`) and for the `sh` steps inside the Jenkinsfile (shell loops to wait for the container, curl/wget fallbacks, etc.).

---

## Technology: Git/GitHub

- **What is it?** A distributed version-control system (Git) plus a hosted platform for remote repositories, pull requests, and webhooks (GitHub).
- **Why do we need it?** Every CI/CD pipeline needs a trigger. Git provides the authoritative history of changes; GitHub provides the remote place Jenkins clones from and the webhook that notifies it.
- **What problem does it solve?** Versioning, collaboration, traceability (each build maps to a commit SHA), and a well-defined "what changed" answer.
- **What happens without it?** No way to reproducibly rebuild a known state, no automatic trigger, and manual copying of code around servers.
- **Why was it selected?** Ubiquitous, free for public repos, first-class webhook + Jenkins plugin support, and branch/PR-based workflows match the project theme.
- **Alternative technologies:** GitLab, Bitbucket, Azure Repos, Gitea.
- **When should we use the alternative?** When you already live in that ecosystem (e.g. GitLab MRs + GitLab CI, or self-hosting Gitea for privacy/air-gapped needs).

## Technology: Jenkins

- **What is it?** The leading open-source automation server, extensible through 1000+ plugins, with declarative *Pipeline as Code*.
- **Why do we need it?** It is the orchestrator that executes the whole pipeline on every commit and reports results (success/failure) with full console logs.
- **What problem does it solve?** Automating build/test/deploy steps that would otherwise be done by hand, and making failures visible and attributable to a stage and a commit.
- **What happens without it?** "It worked on my machine" — nobody automates the flow, and regressions reach production silently.
- **Why was it selected?** Mature, plugin-rich, free, runs anywhere (here: in a container), and it is the classic "GitHub + Jenkins + Docker" learning stack.
- **Alternative technologies:** GitHub Actions, GitLab CI, GitLab CI/CD, TeamCity, CircleCI, Azure DevOps.
- **When should we use the alternative?** When you want to keep CI config next to code on the same platform (GitHub Actions) or avoid running/maintaining a server.

## Technology: Docker

- **What is it?** Containerization: packages an app + its runtime into a portable image; runs it isolated on any host with the Docker engine.
- **Why do we need it?** To (a) build a repeatable artifact and (b) run the app in a clean environment that matches production.
- **What problem does it solve?** "Works on my machine" drift, dependency hell, and inconsistent environments between dev, CI, and prod.
- **What happens without it?** Every environment needs manual Node setup; version mismatches and deployment surprises.
- **Why was it selected?** Ubiquitous standard, lightweight vs VMs, integrates cleanly with Jenkins (docker-workflow plugin + socket mount), and the app is trivial to containerize (zero deps).
- **Alternative technologies:** Podman, containerd + nerdctl, LXC/LXD, VMs (VirtualBox/KVM).
- **When should we use the alternative?** Podman for a daemon-less, rootless, drop-in compatible engine; VMs when strong isolation between workloads is required.

## Technology: Docker Compose

- **What is it?** A declarative tool that defines and runs multi-container apps from a YAML file.
- **Why do we need it?** The Jenkins controller needs many options (ports, env, volumes, mounts); encoding them in a YAML makes the setup reproducible and versionable.
- **What problem does it solve?** Replacing a long, error-prone list of `docker run` flags with a single `docker compose up -d`.
- **What happens without it?** You'd have to remember a dozen CLI flags and retype them on every machine.
- **Why was it selected?** Ships with Docker Desktop, trivial YAML, and it's the standard way to document multi-container dev stacks.
- **Alternative technologies:** Raw `docker run` scripts, Kubernetes, `docker stack deploy`.
- **When should we use the alternative?** Kubernetes when you need production-grade scaling/scheduling; raw `docker run` for one-off throwaway containers.

## Technology: Trivy

- **What is it?** An open-source comprehensive vulnerability scanner for containers, filesystems, and git repos.
- **Why do we need it?** To catch known CVEs in the base image / app dependencies before the image ships.
- **What problem does it solve?** Shipping insecure images with outdated packages that have known exploits.
- **What happens without it?** Vulnerabilities are only discovered (if ever) after deployment or by external audits.
- **Why was it selected?** Free, fast, zero-install option (`docker run aquasec/trivy`), and simple CI integration.
- **Alternative technologies:** Docker Scout, Snyk, Grype/anchore, Clair, JFrog Xray.
- **When should we use the alternative?** Snyk/Scout when you want registry-native scanning with an existing account; Grype when you prefer open-source-only engines.

## Technology: Bash

- **What is it?** The standard Unix shell scripting language.
- **Why do we need it?** For glue code around the pipeline: pre-flight checks, waiting loops, health checks, and `sh` steps inside the Jenkinsfile.
- **What problem does it solve?** Automating the "human" parts of a demo (start Jenkins, print the admin password, curl the app) and making `sh` steps readable.
- **What happens without it?** You'd run every command manually and the Jenkinsfile stages would have no readable logic.
- **Why was it selected?** The Jenkins controller image ships with bash/sh and curl, and the project theme targets Linux/DevOps tooling.
- **Alternative technologies:** PowerShell, Python scripts, `jenkins` shared-library steps.
- **When should we use the alternative?** PowerShell when the demo host is Windows-only and lacks a bash; a shared library when shell glue grows beyond a few lines.

## Full run of one build

1. Developer pushes to GitHub.
2. GitHub webhook (or Jenkins SCM poll) triggers the pipeline job.
3. Jenkins checks out `main` → validates `server.js` → runs `node --test`.
4. Security stage scans with Trivy (skips gracefully if unavailable).
5. `docker build -t hello-app:BUILD_NUMBER ./app`.
6. `docker run -d --name hello-app-N -p 809N:3000 hello-app:N`.
7. `curl http://localhost:809N/health` asserts `{"status":"ok"}`.
8. Cleanup removes the container; `post` block reports success/failure.
