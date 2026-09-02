# Architecture

## Data flow

```
Internet → AWS VPC → Public Subnet → EC2 → Docker → Nginx → Application
```

1. A user hits `http://<public_ip>` on port 80.
2. Traffic enters the **VPC** through the **Internet Gateway**.
3. The **route table** (public subnet) sends `0.0.0.0/0` to the IGW.
4. The **security group** allows the traffic (80/443 from anywhere, 22 from your IP).
5. **Nginx** (running on the EC2 host) receives the request on port 80 and
   reverse-proxies it to `http://127.0.0.1:3000`.
6. The **Docker container** (the app) listens on port 3000 and answers.
7. The response flows back through the same path.

Admin access path: your machine → SSH:22 → EC2 → shell. The box can also be
reached through SSM Session Manager (IAM role attached), which needs no open
port 22.

## Layer by layer

### VPC (`vpc.tf`)
A logically isolated network: `aws_vpc` with `10.0.0.0/16`, DNS hostnames
enabled, tagged `terraform-aws-docker-dev-vpc`.

### Subnet (`subnet.tf`)
`aws_subnet` `10.0.1.0/24` in the first AZ with `map_public_ip_on_launch =
true` (instances get public IPs automatically).

### Internet Gateway + Route Table (`vpc.tf`)
`aws_internet_gateway` attached to the VPC; `aws_route_table` with one route
`0.0.0.0/0 → IGW`; `aws_route_table_association` binds the subnet to that
table. Without these the subnet is "private" and unreachable from the internet.

### Security Group (`security-group.tf`)
Stateful firewall on the instance:
- ingress 22 from `var.allowed_ssh_cidr` (your IP only)
- ingress 80 and 443 from `0.0.0.0/0`
- egress all
The app port 3000 is deliberately **not** exposed to the internet - only local
Nginx talks to it.

### IAM (`iam.tf`)
`aws_iam_role` with an EC2 trust policy → `aws_iam_instance_profile` → attached
to the instance. Policies: `AmazonSSMManagedInstanceCore` (SSM access) + a
minimal inline policy allowing `s3:GetObject` on one placeholder bucket. No
long-lived keys anywhere.

### EC2 (`ec2.tf`)
`aws_instance` (`count = instance_count`): latest Ubuntu 24.04 AMI via
`data "aws_ami"`, `data "aws_availability_zones"` for the AZ, instance type from
`variables.tf`, key pair, subnet + SG + instance profile, and `user_data` =
base64 of `user-data.sh` with `user_data_replace_on_change = true`.

### user-data (`user-data.sh`)
EC2 bootstrap: `set -euo pipefail`; apt update; install `docker.io` + `nginx`;
enable/start both; `docker run -d -p 3000:3000 <image>`; write an Nginx
`app` site (reverse proxy to `127.0.0.1:3000`) via heredoc; enable it; `nginx -t`;
reload; write `USER DATA COMPLETE` to `/tmp/user-data-complete.log`.

### Docker (`app/Dockerfile`)
The app is packaged as a small container: `node:20-alpine`, only `package.json`
+ `server.js` copied (zero npm dependencies), port 3000, a HEALTHCHECK hitting
`/health`, `CMD ["node", "server.js"]`.

### Nginx
Reverse proxy and single public entry point. It terminates the public HTTP
request and forwards to the container's `127.0.0.1:3000`, passing host/real-IP
headers. This keeps port 3000 off the internet and gives you a place to add TLS,
caching, gzip, rate limiting, etc. later.

---

# Technology: WHY

## Terraform
- **What is it?** HashiCorp's Infrastructure-as-Code tool. Declarative HCL files
  describe desired infrastructure; Terraform builds a graph, diffs it against
  state, and creates/updates/destroys resources.
- **Why do we need it?** To provision the entire AWS stack repeatably from code
  instead of by hand.
- **What problem does it solve?** Drift, inconsistency, forgetfulness, and the
  impossibility of reproducing a "clicked-together" environment.
- **What happens without it?** The stack is rebuilt manually each time: errors,
  inconsistent configs, no audit trail, no rollback.
- **Why was it selected?** Cloud-agnostic, HCL is readable, huge module
  ecosystem, works from any laptop or CI runner, no extra AWS components needed.
- **Alternative technologies:** CloudFormation, CDK, Pulumi, Ansible (not IaC
  in the same sense - config management), manual console.
- **When should we use the alternative?** CloudFormation when fully AWS-locked
  and you want native stack features; CDK/Pulumi when you want real programming
  languages; Ansible when the goal is configuring machines rather than
  provisioning cloud resources.

## AWS
- **What is it?** Amazon Web Services - the cloud provider hosting the
  infrastructure (compute, networking, identity).
- **Why do we need it?** To actually run the app - no self-hosted hardware.
- **What problem does it solve?** On-demand compute/networking/identity with
  pay-as-you-go pricing.
- **What happens without it?** You'd need to buy/rent servers and build a data
  center, or use another provider.
- **Why was it selected?** Industry standard, richest service catalog, best
  documentation and community, generous free tier.
- **Alternative technologies:** GCP, Azure.
- **When should we use the alternative?** When the org already runs on them, or
  you need their specific services/budget agreements.

## VPC
- **What is it?** A logically isolated private network inside AWS with your own
  CIDR blocks.
- **Why do we need it?** To give resources an isolated network boundary and
  control routing (public/private segments).
- **What problem does it solve?** Default/shared networking leaks resources and
  prevents clean security boundaries.
- **What happens without it?** Instances would live in a shared, less-controlled
  network (or the default VPC you don't own).
- **Why was it selected?** Foundation of all AWS networking; teaches the core
  isolation model; free to create.
- **Alternative technologies:** Default VPC, shared VPCs, transit gateways.
- **When should we use the alternative?** Default VPC for throwaway tests; shared
  VPCs in large orgs that centralize networking.

## EC2
- **What is it?** Elastic Compute Cloud - resizable virtual servers.
- **Why do we need it?** To run Docker, Nginx, and the app as a real always-on
  service.
- **What problem does it solve?** Instant, controllable compute without buying
  hardware.
- **What happens without it?** No place to run the containerized app.
- **Why was it selected?** Full control, simple, free-tier friendly, and the
  standard "server" that everything else builds on.
- **Alternative technologies:** Fargate, ECS, EKS, Lambda, Lightsail.
- **When should we use the alternative?** When you want to stop patching hosts
  (Fargate/Lambda) or scale out containers without managing instances.

## Security Groups
- **What is it?** Virtual stateful firewalls attached to instances.
- **Why do we need it?** To control exactly which traffic reaches the instance
  (22 from your IP; 80/443 from anywhere; everything else blocked).
- **What problem does it solve?** Without it every open port is exposed to the
  internet; it is the first line of defense.
- **What happens without it?** Instance is reachable on any port = trivially
  compromised.
- **Why was it selected?** Native, stateful, no host config needed, enforced
  outside the OS.
- **Alternative technologies:** NACLs, host firewalls (iptables/ufw), WAF.
- **When should we use the alternative?** NACLs for subnet-level defense-in-depth
  at scale; host firewalls when you can't trust network-layer rules alone; WAF
  for HTTP-layer filtering on web endpoints.

## IAM
- **What is it?** Identity and Access Management - who can do what on AWS.
- **Why do we need it?** To give the instance permissions without baking keys
  into it (role + instance profile) and to restrict what it can do.
- **What problem does it solve?** Long-lived access keys in files/env vars get
  stolen; roles give short-lived, scoped, rotating credentials.
- **What happens without it?** You either paste keys everywhere (security
  nightmare) or the instance can't use AWS services at all.
- **Why was it selected?** The native, least-privilege mechanism; also enables
  SSM (keyless access).
- **Alternative technologies:** Access keys, static credentials, third-party
  identity federation.
- **When should we use the alternative?** Access keys only for CLIs on your own
  laptop; federation (SSO/OIDC) for humans in a company setting.

## Docker
- **What is it?** Containerization - packages the app with its runtime into a
  lightweight, isolated image.
- **Why do we need it?** "It works on my machine" - the container runs identically
  anywhere Docker runs.
- **What problem does it solve?** Dependency conflicts, version skew between
  environments, slow/error-prone deployment.
- **What happens without it?** Every host needs its own manual Node install and
  version management; environments drift apart.
- **Why was it selected?** Ubiquitous, lightweight, huge image ecosystem, perfect
  for a single-service app.
- **Alternative technologies:** Podman, containerd, VMs, native installs.
- **When should we use the alternative?** Podman for rootless/daemonless needs;
  VMs when you need full OS isolation.

## Nginx
- **What is it?** A high-performance web server and reverse proxy.
- **Why do we need it?** Single public entry point that forwards traffic to the
  app container on port 3000.
- **What problem does it solve?** Keeping the app port off the public internet
  while adding a standard place for TLS, logging, caching, and rate limiting.
- **What happens without it?** You'd expose port 3000 directly (messier URLs,
  no proxy layer, no easy TLS/caching later).
- **Why was it selected?** Fast, configurable via text files, battle-tested,
  installed from apt in seconds.
- **Alternative technologies:** Apache, Caddy, HAProxy, ALB (managed).
- **When should we use the alternative?** Caddy for automatic HTTPS; HAProxy for
  TCP load balancing; ALB when you want a managed, auto-scaling front door.
