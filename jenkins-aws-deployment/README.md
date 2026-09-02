# Jenkins AWS Deployment

Automated CI/CD from Git push to AWS EC2 — Jenkins builds a Docker image, ships it to EC2 via SSH, and runs it behind Nginx with health checks and rollback.

## Overview

This repository delivers a Node.js web application to a single AWS EC2 host through a Jenkins declarative pipeline. On `git push`, Jenkins tests the code, builds an immutable image `node-app:BUILD_NUMBER`, optionally scans it with Trivy, transfers it with `docker save | ssh | docker load` (or `ECR` when `USE_REGISTRY=true`), stops the old container, starts the new one bound to `127.0.0.1:3000`, and gates success on `curl /health`. Nginx on port 80 is the public entry point.

**Real-world problem it solves:** manual SSH deploys are untraceable and unsafe; this makes every deploy versioned, verified, and revertible.

```
Git push --> GitHub --> Jenkins --> Test --> Docker Build --> Trivy --> Transfer --> EC2: deploy.sh --> Nginx :80 --> Container 127.0.0.1:3000 --> Health Check --> Rollback on failure
```

## Architecture

```mermaid
flowchart TD
    A[Git Push] --> B[Jenkins]
    B --> C[Test node --test]
    C --> D[Docker Build node-app:N]
    D --> E[Trivy]
    E --> F[docker save|ssh docker load]
    F --> G[EC2 Ubuntu]
    G --> H[Nginx :80]
    H --> I[node-app :3000]
    I --> J[Health curl]
    J -->|fail| K[rollback.sh previous tag]
```

EC2 bootstrap `scripts/ec2-bootstrap.sh` installs Docker Engine, enables it, stages `ufw` (22/80/443), and pulls `nginx:alpine`.

## Technologies

| Technology | Purpose |
|---|---|
| Git / GitHub | VCS and trigger |
| Jenkins (declarative) | CI/CD orchestration |
| Docker | Image build / transfer / run |
| AWS EC2, Security Groups | Compute and firewall |
| Nginx | Reverse proxy 80 → 127.0.0.1:3000 |
| Node.js | App runtime (zero deps) |
| Trivy | Image scan (optional) |
| Bash | Bootstrap, deploy, rollback, healthcheck |

## Features

- Immutable per-build tags `node-app:BUILD_NUMBER` + `latest`, `ARG BUILD_VERSION` baked into image label
- Two transfer modes: SSH direct (`docker save/load`, zero registry credentials) or registry (`USE_REGISTRY=true` + `docker push/pull` via `dockerhub` credential)
- `127.0.0.1:3000` container bind — only Nginx is public (documented in `nginx/app-proxy.conf`)
- Retry loops: `deploy.sh` (15×3s), Jenkins `Health Check` (curl public IP), Docker `HEALTHCHECK`
- Automatic rollback: on health failure deploys `PREV_IMAGE_TAG` (`BUILD_NUMBER-1`) via `rollback.sh`
- EC2 bootstrap idempotent, marker `/opt/devops/bootstrap-done`

## Prerequisites

- AWS account + IAM EC2 permissions, `aws configure`
- Docker + Node 18+ locally (for `LOCAL TEST`)
- Jenkins (native or Docker) with `git`, `docker`, `sshagent` plugins
- EC2 key pair in target region, Security Group allowing SSH from your IP and HTTP 80
- Optional Trivy on Jenkins agent

## Setup

```bash
git clone <this-repo> && cd jenkins-aws-deployment
cp .env.example .env   # set EC2_HOST, APP_PORT etc. (never commit .env)
```

**EC2:** Launch Ubuntu 22.04/24.04 with `scripts/ec2-bootstrap.sh` as User Data (or `sudo bash ec2-bootstrap.sh` on an existing host). SG: 22 from your IP, 80 from `0.0.0.0/0`. Install `nginx` and copy `nginx/app-proxy.conf` → `/etc/nginx/conf.d/app-proxy.conf` → `nginx -t && systemctl reload nginx`.

**Jenkins:** In Manage Jenkins → Credentials, create `ec2-key` (SSH Username `ubuntu` + private key), and `github-creds` if private repo. Add global env `EC2_PUBLIC_IP` or build parameter. Create Pipeline job, SCM = this repo, Script Path `Jenkinsfile`.

Details: `docs/setup.md`.

## Configuration

| Item | Location | Notes |
|---|---|---|
| Image | `Jenkinsfile` `IMAGE=node-app:${BUILD_NUMBER}` | registry prefix if using ECR |
| Container | `CONTAINER_NAME=node-app`, `APP_PORT=3000`, bind `127.0.0.1:APP_PORT` | see `scripts/deploy.sh` |
| Nginx | `nginx/app-proxy.conf` | `upstream node_app_backend 127.0.0.1:3000; keepalive 8` |
| Jenkins vars | `EC2_PUBLIC_IP`, `USE_REGISTRY`, `IMAGE_ARCHIVE` | never hardcode IP in Jenkinsfile |
| Credentials | `ec2-key`, `github-creds`, `dockerhub` | via `sshagent` / `withCredentials` |
| App env | `BUILD_VERSION`, `PORT` | shown on HTML `/` |

## Deployment

**Local (no AWS):**

```bash
cd app
docker build --build-arg BUILD_VERSION=local -t node-app:local .
docker run -d --name node-app -p 127.0.0.1:3000:3000 -e BUILD_VERSION=local node-app:local
curl http://127.0.0.1:3000/health
```

**Via Jenkins to EC2:**

```bash
git add . && git commit -m "feat: ..." && git push
# Jenkins: Checkout → Test → Docker Build → Trivy → Transfer → Deploy → Health Check
curl http://<EC2_PUBLIC_IP>/health
```

Scripts executed on EC2 via `sshagent`: `scp deploy.sh/rollback.sh/healthcheck.sh` → `bash /opt/devops/deploy.sh` with `IMAGE`, `BUILD_VERSION`, `PREV_IMAGE_TAG` env.

See `docs/deployment.md`.

## Testing

```bash
cd app
node --check server.js
PORT=34568 node --test   # 4 tests if host 3000 busy
docker build -t node-app:test ./app && echo OK
```

Tests: `GET /health` 200 + `buildVersion`, `GET /` 200 HTML, `GET /api/message` 200, `GET /unknown` 404.

Jenkins runs `sh 'node --test'` in `Test` stage.

## Monitoring / Logging

- EC2: `docker logs --tail 50 node-app`, `systemctl status docker nginx`, `docker stats`, `tail -f /var/log/nginx/access.log`
- Jenkins: `Health Check` stage curls public `http://EC2_IP/health` + EC2 loopback `http://127.0.0.1/health`
- Docker `HEALTHCHECK` polls `http://127.0.0.1:3000/health`

## Security

- `.env`, `*.pem`, `*.key` gitignored; only `.env.example` committed
- IAM least privilege for deploy user; SSH key `chmod 400`, `StrictHostKeyChecking=accept-new`, `sshagent`
- SG least privilege: SSH from your IP, HTTP 80 public; container not exposed (loopback bind)
- Jenkins Credentials store for `ec2-key`, `github-creds`; `Jenkinsfile` references by ID only
- App `USER appuser` (UID 1001) non-root, Docker `HEALTHCHECK` via `wget`
- Trivy scan with warning-or-skip if binary missing; enforce by switching `--exit-code 1`

## Cleanup

```bash
# EC2
aws ec2 describe-instances --filters Name=tag:Name,Values=node-app --query 'Reservations[].Instances[].InstanceId'
aws ec2 terminate-instances --instance-ids <id>
# Local images/containers
docker rm -f node-app 2>/dev/null || true
docker image prune -f
```

Always verify in Billing that instance is terminated; stopped instances still charge for EBS.

## Project Structure

```
jenkins-aws-deployment/
├── README.md
├── Jenkinsfile
├── .env.example
├── .dockerignore
├── .gitignore
├── app/
│   ├── Dockerfile
│   ├── package.json
│   ├── server.js
│   └── test/test.js
├── nginx/
│   └── app-proxy.conf
├── scripts/
│   ├── ec2-bootstrap.sh
│   ├── deploy.sh
│   ├── rollback.sh
│   └── healthcheck.sh
├── docs/
├── diagrams/
└── screenshots/
```

## Future Improvements

- ECR + ALB + Auto Scaling Group for HA
- IAM instance profile instead of static key
- Terraform for VPC/SG/EC2 as code (see companion `terraform-aws-infrastructure`)
- Blue/green or canary deploys, CloudWatch alarms, `certbot` TLS
