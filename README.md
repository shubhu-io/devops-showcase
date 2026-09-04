# DevOps Portfolio

Production-inspired, standalone DevOps projects — each repository is self-contained and ready to present to a recruiter or interviewer.

> Each project below runs independently. Clone any single repository and follow its README — no prior project or external context required.

---

## Repositories

| Repository | What it does | Key technologies |
|---|---|---|
| [`linux-nginx-server`](https://github.com/shubhu-io/linux-nginx-server) | Secure Linux + Nginx web server with systemd supervision and git-based deploys | Ubuntu, Nginx, systemd, ufw, SSH, Bash |
| [`dockerized-web-application`](https://github.com/shubhu-io/dockerized-web-application) | Multi-container app with Nginx → Node.js → PostgreSQL, isolated network and persistent volume | Docker, Docker Compose, Nginx, Node.js, PostgreSQL |
| [`jenkins-cicd-pipeline`](https://github.com/shubhu-io/jenkins-cicd-pipeline) | Jenkins declarative pipeline that builds, tests, scans, and health-checks a containerized app | Jenkins, Docker, Trivy, Node.js, Bash |
| [`jenkins-aws-deployment`](https://github.com/shubhu-io/jenkins-aws-deployment) | End-to-end deploy from Git push to AWS EC2 via Jenkins, SSH, and Nginx reverse proxy | Jenkins, Docker, AWS EC2, Nginx |
| [`terraform-aws-infrastructure`](https://github.com/shubhu-io/terraform-aws-infrastructure) | Terraform-provisioned AWS stack (VPC, subnet, SG, IAM, EC2) booting Docker + Nginx via user-data | Terraform, AWS, Docker, Nginx, Node.js |
| [`kubernetes-application-deployment`](https://github.com/shubhu-io/kubernetes-application-deployment) | K8s Deployment/Service/Ingress/HPA with probes and securityContext for the demo app | Kubernetes, Docker, Node.js |
| [`ansible-server-configuration`](https://github.com/shubhu-io/ansible-server-configuration) | Idempotent Ansible roles to configure Ubuntu+Nginx (common/nginx/app) via `ansible-playbook` | Ansible, Ubuntu, Nginx, systemd, Jinja2 |
| [`github-actions-cicd`](https://github.com/shubhu-io/github-actions-cicd) | GitHub Actions CI (lint/test/build/health) and GHCR publish (Buildx, OIDC) | GitHub Actions, Docker, GHCR, Node.js |

## Additional Standalone Repositories

| Repository | What it does | Key technologies |
|---|---|---|
| [`git-terraform-vpc`](https://github.com/shubhu-io/git-terraform-vpc) | Terraform VPC topology scaffold — VPC, subnets, gateways, bastion, web, DB (work in progress) | Terraform, AWS |
| [`jenkins`](https://github.com/shubhu-io/jenkins) | Jenkins administration & operations scripts, configs, and guides | Jenkins, Bash, Docker |
| [`jenkins-script`](https://github.com/shubhu-io/jenkins-script) | Large Jenkins script collection — AWS helpers, Helm, pipelines, installation guides | Jenkins, Bash, AWS, Helm |
| [`jenkins-terraform`](https://github.com/shubhu-io/jenkins-terraform) | Jenkins controller + portfolio app EC2 on AWS provisioned with Terraform | Terraform, AWS, Jenkins, Nginx |
| [`mern-stack-using-terra`](https://github.com/shubhu-io/mern-stack-using-terra) | MERN-style Node.js app on AWS — VPC, ALB, ASG, MongoDB via Terraform | Terraform, AWS, Node.js, MongoDB |

---

## How to Use

- **Hiring manager / recruiter:** open any repository above — its README explains the problem, architecture, security, how to run it, and how to clean it up.
- **Learner:** pick the stack you need. Want containers? Start with `dockerized-web-application`. Want IaC? Start with `terraform-aws-infrastructure`.

All projects are local-first where possible; cloud projects include a `LOCAL TEST` path that requires no AWS spend. Where AWS is required, cost warnings and `terraform destroy` / `terminate` steps are documented.

---

## Common Principles

- **Real code, not slides** — every config runs (`nginx -t`, `docker compose config`, `terraform validate`).
- **Never commit secrets** — `.env`, `*.pem`, `*.tfvars`, `*.tfstate` are gitignored; only `*.example` files are committed.
- **Documented, not fabricated** — screenshots are captured per `screenshots/README.md`, not faked.
- **Verified** — tests run: `node --test`, `bash tests/*.sh`, `terraform fmt/validate`, `curl /health`.

---

## Repository Structure

```
.
├── linux-nginx-server/
├── dockerized-web-application/
├── jenkins-cicd-pipeline/
├── jenkins-aws-deployment/
├── terraform-aws-infrastructure/
├── kubernetes-application-deployment/
├── ansible-server-configuration/
├── github-actions-cicd/
├── README.md
├── LICENSE
└── .gitignore
```

Each repository follows the same internal layout:

```
repo/
├── README.md
├── docs/
├── diagrams/
├── screenshots/
└── source files (Dockerfile, Jenkinsfile, *.tf, nginx/*.conf, scripts/*)
```

---

## Prerequisites (portfolio-wide)

- Git, Bash, text editor
- Docker Engine 24+ with Compose v2 (for container projects)
- Node 18+ optional for local app checks
- Terraform >= 1.5 + AWS CLI v2 (for `terraform-aws-infrastructure` and cloud deploy)
- Ubuntu 22.04/24.04 VM (for `linux-nginx-server`)

See each repository’s `Prerequisites` section for exact requirements.

---

## Security Notes

- Least privilege: non-root containers (`USER node`/`appuser`), `webuser` for web root, IAM role with minimal S3 + SSM, SG allows SSH only from your IP.
- Firewalling: `ufw` (Linux host) or Security Groups (AWS).
- Host hardening: systemd `NoNewPrivileges`, `PrivateTmp`, encrypted EBS, IMDSv2, `server_tokens off`, security headers.
- Supply chain: multi-stage builds (minimal images), Trivy scanning in pipelines.
- Secrets: Jenkins Credentials store, `.env` gitignored, Terraform state local and ignored.

---

## License

[MIT License](LICENSE)

---

## Disclaimer

For learning and portfolio use. Production use requires adapting security, compliance, and cost controls to your environment. Destroy cloud resources when finished.
