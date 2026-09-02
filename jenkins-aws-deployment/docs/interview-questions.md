# Interview Questions & Answers

Twelve questions with concise, accurate answers grounded in this project.

---

## Q1. What is EC2?

EC2 (Elastic Compute Cloud) is AWS's IaaS offering — a virtual machine you rent by
the second. You choose an AMI (OS image), instance type (CPU/RAM), storage, key
pair (SSH auth) and a security group (firewall). In this project the EC2 instance
is the Ubuntu host that runs Docker, Nginx, and the app container.

## Q2. What is a security group?

A stateful virtual firewall attached at the VPC level to instances (or other AWS
resources). It has allow-only inbound and outbound rules. Here it allows SSH on 22
from our IP only and HTTP on 80 from anywhere, so the app is public but admin
access is not.

## Q3. How do you pass secrets to Jenkins?

Via the Jenkins Credentials store, referenced by ID in the pipeline. Examples:
`ec2-key` (SSH private key used by `sshagent`), `github-creds` (repo checkout
token), and `dockerhub` (registry login via `withCredentials`). Values are
encrypted at rest and masked in build logs; the pipeline never contains literal
secrets. Global, non-secret config like the EC2 public IP goes in Jenkins'
environment variables or build parameters.

## Q4. How does Jenkins deploy to EC2?

The Jenkinsfile runs stages: checkout → `node --test` → `docker build` → optional
Trivy scan → image transfer → remote deploy → health check. The Deploy stage uses
`sshagent('ec2-key')` to authenticate SSH, `scp`s the deploy scripts to
`/opt/devops/`, and runs `deploy.sh`, which stops the old container and starts the
new one with `docker run -d --restart unless-stopped -p 127.0.0.1:3000:3000
-e BUILD_VERSION=...`. Nginx already listens on 80 and proxies to 3000.

## Q5. What is a user-data script?

A script passed to EC2 at launch that cloud-init executes automatically on first
boot. `scripts/ec2-bootstrap.sh` installs Docker, enables the daemon, stages ufw
rules, pulls the nginx image, and writes a `bootstrap-done` marker — so every
instance comes up fully configured and identical.

## Q6. What is a key pair (.pem) and why `chmod 400`?

EC2 key pairs are asymmetric SSH credentials: the public half goes on the instance
(in `~/.ssh/authorized_keys`), the private half (`.pem`) stays with you. `chmod
400` removes read access for group/other so only your user can read it — OpenSSH
refuses to use keys that are too permissive. The key grants full shell access, so
it must be protected like a password.

## Q7. How do you rollback a bad deploy?

Containers make rollback a tag swap. The pipeline tags each build
`node-app:<BUILD_NUMBER>`. On failure, `rollback.sh` stops the current container
and re-runs the previous tag: `TAG=node-app:82 bash /opt/devops/rollback.sh`,
then health-checks. In registry/blue-green setups you'd instead repoint traffic
(ALB target or Nginx upstream reload) to the previous image.

## Q8. Why put Nginx in front of the app container?

Separation of concerns: Nginx owns the public surface (port 80, headers, TLS,
static files, rate limiting) while the Node container stays private on localhost.
It also gives a single entry point where multiple app instances can later be load
balanced, and it decouples app networking from the internet.

## Q9. How do you secure SSH?

- Key-pair auth only, passwords disabled in `sshd_config`.
- Security group restricts 22 to my IP (`/32`).
- `chmod 400` on the private key.
- fail2ban to block brute-force attempts.
- Non-root user (`ubuntu`) with sudo; keep `authorized_keys` minimal.
- Keep the system patched.

## Q10. What's the difference between image transfer and a registry?

Transfer = `docker save` the image to a tar and pipe it over SSH to the host's
`docker load`. No registry or credentials, but slower and no central inventory.
Registry = `docker push` to ECR/Docker Hub and the host does `docker pull`. Faster
for big images, has audit/versioning, and is the pattern you need for multi-host
or cluster deployments — at the cost of credentials and an extra service.

## Q11. How would you make this HA (high availability)?

- Run the app on ≥2 EC2 instances in different AZs behind an Application Load
  Balancer (health checks + auto-scaling via ASG) — or move to ECS/Fargate with
  service auto-scaling.
- Multi-AZ RDS/database (or managed service) for state; stateless app tiers.
- Registry-based images (ECR) so any host can pull any version.
- Add deployment strategies like blue/green or canary with automated rollback.

## Q12. How do you monitor a deployed app?

Three layers here: (1) health checks — `curl /health` from deploy.sh, the pipeline,
and the Docker HEALTHCHECK; (2) logs — `docker logs node-app` and
`journalctl -u nginx` on the host; (3) metrics — container stats (`docker stats`),
and the growth path to Prometheus/Grafana, CloudWatch, or an APM tool, plus
uptime checks (UptimeRobot/Pingdom) against `/health`.
