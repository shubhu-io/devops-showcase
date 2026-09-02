# Architecture

## High-level flow

```
Developer ──git push──▶ GitHub ──webhook──▶ Jenkins
                                                │  checkout ─▶ node --test ─▶ docker build
                                                │  trivy scan ─▶ docker save | ssh | docker load
                                                ▼
                                          AWS EC2 (Ubuntu)
                                                │  docker run -d -p 127.0.0.1:3000:3000
                                                ▼
                                     App Container (:3000)  ◀── Nginx (:80)
                                                │                    ▲
                                                └── curl /health ────┘
                                                                     Internet users
```

**Full pipeline:** Git Push → Jenkins Trigger → Checkout → Test → Build Docker Image →
Deploy to EC2 → Start Container → Health Check. A failing health check triggers the
rollback hook which re-runs the previous image tag.

## Component interactions

| Component | Runs where | Role in this project |
|---|---|---|
| GitHub | SaaS | Source of truth; the trigger for the pipeline via webhook |
| Jenkins | Dev machine (or separate EC2) | Orchestrates checkout, tests, image build, transfer, deploy, health check |
| Docker Engine | Jenkins + EC2 | Builds the image on Jenkins; runs the container on EC2 |
| Docker image | Transferred artifact | Tagged `node-app:<BUILD_NUMBER>` and `node-app:latest` |
| EC2 | AWS | Long-running VM that hosts Docker + Nginx + the app container |
| Nginx | EC2 host | Reverse proxy on port 80 forwarding to the app container on 3000 |
| Security group | AWS (VPC) | Stateful firewall: 22 from your IP, 80 from everywhere |

---

## Technology deep-dives ("Why?" sections)

### 1. AWS EC2

**What is it?**
EC2 (Elastic Compute Cloud) is a virtual machine in the AWS cloud. You provision
one with an AMI (OS image), instance type (CPU/RAM), key pair (SSH access), and a
security group (firewall). Billing is per-second while the instance is running.

**Why do we need it?**
Every deployed web app needs a server. EC2 gives us a public IP + port 80 reachable
from the internet where we can run the Nginx + Docker container stack.

**What problem does it solve?**
It removes the need to buy/rack physical hardware. A VM is available in minutes,
scoped to a specific OS (Ubuntu 22.04/24.04) and sized for our workload.

**What happens without it?**
We would have no public host to run the app; the pipeline would stop at "image
built on the laptop". There'd be nothing reachable over the internet.

**Why was it selected?**
- Familiar `ssh ubuntu@IP` workflow fits a learning project.
- Full control: we install Docker and Nginx ourselves (transparent).
- Free-tier eligible (`t2.micro`/`t3.micro`), cheap to test.
- No platform lock-in to a PaaS that hides the OS.

**Alternative technologies:**
AWS ECS/Fargate (managed containers), AWS Elastic Beanstalk (PaaS),
EC2 Instance Connect / Lightsail (simpler VM), other clouds (GCP GCE, Azure VMs),
or a local server.

**When should we use the alternative?**
Use Fargate/ECS when you don't want to manage a VM or need scaling/ALB built in.
Use a PaaS when you only care about the app and not the server. Use Lightsail if
you want a flat-pricing VM with a friendlier console.

### 2. SSH

**What is it?**
The Secure Shell protocol gives an encrypted, authenticated remote command line.
Authentication here is a key pair: the private `.pem` stays on your/Jenkins machine,
the public half is trusted by the instance (stored in `~/.ssh/authorized_keys`).

**Why do we need it?**
- You: to configure the EC2 host (install Nginx, inspect containers).
- Jenkins: to `scp` deploy scripts and the app image and to run `docker run`
  on the remote host without opening any port other than 22.

**What problem does it solve?**
It replaces unencrypted, password-based `telnet`/`rsh`. Even though 22 is open on
the security group, without the private key nobody can log in.

**What happens without it?**
There is no way to administer the host. A public web host you can't SSH into can't
be patched, debugged, or deployed to.

**Why was it selected?**
Standard, ubiquitous, scriptable non-interactively in Jenkins (via `sshagent`),
and the de-facto way to reach Linux VMs.

**Alternative technologies:**
EC2 Instance Connect (browser/API-based SSH via the AWS console, needs the
ec2-instance-connect agent), AWS SSM Session Manager (no public port at all),
cloud-init/Chef/Ansible (config management instead of ad-hoc commands).

**When should we use the alternative?**
Use SSM Session Manager when you don't want port 22 exposed at all. Use Instance
Connect when you want to avoid distributing `.pem` files to teammates.

### 3. Jenkins

**What is it?**
A self-hosted CI/CD automation server. Jobs are defined in the `Jenkinsfile`
(declarative pipeline) committed to the repo, so the pipeline is versioned with the
code. It runs stages (Checkout, Test, Docker Build, Deploy, Health Check) on agents.

**Why do we need it?**
Someone must react to `git push`, run tests, build the image, and push it to EC2.
Jenkins turns that into an automatic, repeatable pipeline instead of manual
commands typed by a developer.

**What problem does it solve?**
Manual deploy steps are slow, error-prone, and untraceable. Jenkins gives: a single
trigger point, logs for every stage, a build number to tag images, credential
management (sshagent), and automatic rollback on failure.

**What happens without it?**
Deploys depend on a human remembering the right commands and the right order. No
build numbers, no audit trail, no automated rollback — "works on my machine"
problems ship to production.

**Why was it selected?**
- Industry-standard CI/CD, free/open-source.
- Declarative pipelines in Groovy are easy to review in the repo.
- First-class Docker, SSH (`sshagent`), and credentials plugins.
- Runs locally (we use it in this project) or on EC2.

**Alternative technologies:**
GitHub Actions, GitLab CI, Travis, CircleCI, Drone, Azure DevOps Pipelines,
Argo CD (CD-only), Buildkite.

**When should we use the alternative?**
Use GitHub Actions when you don't want to host a CI server and your repo is already
on GitHub. Use GitLab CI when you self-host GitLab. Use Argo CD when you move to a
Kubernetes cluster.

### 4. Docker

**What is it?**
Containerization: the app, its runtime (Node 20), and config are baked into an
image. `docker run` executes it in an isolated namespace on the host kernel. We
build the image on Jenkins and run the container on EC2.

**Why do we need it?**
"Works on my machine" — the image guarantees the EC2 environment matches the build
environment exactly. It also makes deploy and rollback a single atomic operation
(`docker run <tag>`, swap the tag to roll back).

**What problem does it solve?**
Version pinning of dependencies and runtime; one command to start/stop; declarative
health checks; `--restart unless-stopped` for self-healing; immutability (we never
patch a running container, we replace it).

**What happens without it?**
We'd install Node directly on EC2 and `git pull` + `npm install` on the host. Any
host drift (different npm versions, leftover files) breaks deployments, and
rollback means editing files on the server.

**Why was it selected?**
- Widespread, well-documented, works great with Jenkins and EC2.
- Enables the image-transfer deploy pattern and clean tag-based rollback.
- Health checks + restart policies built in.

**Alternative technologies:**
Podman (daemonless containers), containerd directly, systemd services running the
bare Node process, LXC, Vagrant VMs, Kubernetes (orchestration).

**When should we use the alternative?**
Use systemd + bare process when there's a single tiny app and no need for image
portability. Use Kubernetes/containerd when you need multi-node scheduling and
scaling beyond a single host.

### 5. Nginx

**What is it?**
A high-performance web server and reverse proxy. Here it listens on port 80 and
forwards every request to the app container on `127.0.0.1:3000`.

**Why do we need it?**
A public web app needs port 80 served by something robust. Nginx owns the public
surface while the Node container stays private — a defense-in-depth separation.

**What problem does it solve?**
- Reverse proxy (browser talks to Nginx, not to Node directly).
- Single entry point: later add TLS (HTTPS), static files, gzip, rate limiting,
  and load balancing to multiple app containers behind one Nginx.
- Hides the app port; the container isn't exposed on the internet.

**What happens without it?**
The app container would be published directly on port 80. Adding HTTPS, caching,
or a second instance later means rebuilding the app or opening more ports.

**Why was it selected?**
Nginx is the de-facto standard reverse proxy: tiny footprint, battle-tested,
Debian/Ubuntu package. It also matches the classic "Nginx front + container
backend" production pattern.

**Alternative technologies:**
Apache httpd (mod_proxy), HAProxy, Caddy (automatic TLS), Envoy, Traefik
(container-native), or a managed ALB/NLB from AWS.

**When should we use the alternative?**
Use Caddy when you want HTTPS with zero config. Use Traefik when the proxy itself
should be a container that auto-discovers services. Use an AWS ALB when you scale
to multiple EC2 instances and need a load balancer in front.

### 6. AWS Security Groups

**What is it?**
A stateful virtual firewall attached to the instance at the VPC level. Rules are
allow-only: inbound rules define what can reach the instance (e.g. SSH 22 from your
IP, HTTP 80 from everyone), outbound rules define what the instance may reach.

**Why do we need it?**
Without rules, an EC2 instance is reachable on every port from the whole internet —
a welcome mat for attackers. The security group is the *primary* firewall; the
host's `ufw` is only defense-in-depth.

**What problem does it solve?**
Least-privilege exposure: SSH only from your IP, HTTP only on 80. Stateful means
reply traffic is allowed automatically (no separate outbound rule for responses).

**What happens without it?**
Open the wrong port and you expose Node/Nginx admin interfaces or the Docker socket
to the internet. Scan-friendly misconfiguration is one of the top causes of
compromised cloud servers.

**Why was it selected?**
It's the standard AWS mechanism; zero cost; changes apply instantly; it's
inspectable and easy to document (we show ours in the screenshots).

**Alternative technologies:**
Network ACLs (stateless, subnet-level), host firewall only (ufw/iptables),
VPC + private subnets + bastion host, or a WAF for HTTP-level filtering.

**When should we use the alternative?**
Use network ACLs when you need subnet-wide stateless control. Use a private subnet
+ bastion when the app must not be reachable at all from the internet.

### 7. User-data script

**What is it?**
A script (here `scripts/ec2-bootstrap.sh`) you paste into the EC2 launch wizard
"User data" field. cloud-init runs it automatically on first boot, so the instance
comes up already configured: Docker installed + enabled, ports allowed, nginx image
pulled, `/opt/devops/bootstrap-done` marker written.

**Why do we need it?**
Configuring a fresh Ubuntu box by hand takes 15+ minutes of repetitive steps. The
user-data script makes provisioning one-shot, repeatable, and reviewable in git.

**What problem does it solve?**
Bootstrap drift: "I installed Docker once, but this new instance doesn't have it."
A scripted bootstrap guarantees every EC2 host is identical and self-documenting.

**What happens without it?**
You'd SSH in and type the install steps, hoping you don't miss one. New instances
are born unconfigured and every change lives in someone's head.

**Why was it selected?**
Free, built into EC2, executes as root on first boot, and it's just a bash file we
can version in this repo.

**Alternative technologies:**
Ansible playbooks, Terraform `user_data` blocks, AWS AMIs baked with Packer,
cloud-init's own YAML config, SSM Run Command for ongoing drift correction.

**When should we use the alternative?**
Use Packer to bake a ready AMI when boot time and consistency matter most. Use
Terraform to manage the whole infrastructure (VPC, instance, security group) as
code. Use Ansible for ongoing configuration of existing hosts.
