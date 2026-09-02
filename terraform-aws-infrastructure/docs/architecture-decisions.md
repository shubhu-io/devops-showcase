# Architecture Decision Records (ADR)

Each ADR captures a decision, why it was made, what the alternatives were, why
they were rejected, and the consequences.

---

## ADR 001: Infrastructure as Code with Terraform

- **Status**: Accepted
- **Decision**: All infrastructure (VPC, subnet, IGW, route table, SG, IAM,
  EC2) is defined declaratively in HCL and provisioned with Terraform.
- **Why**: Reproducible, reviewable, version-controlled infrastructure. Anyone
  can rebuild the exact stack; changes are reviewed as diffs before they hit AWS.
- **Alternatives**: AWS CloudFormation, AWS CDK, Pulumi, manual console clicks.
- **Why not**:
  - CloudFormation - AWS-locked, verbose YAML/JSON, less flexible templating.
  - CDK/Pulumi - full programming languages add complexity and a bigger runtime
    surface for a small stack.
  - Manual console - not reproducible or auditable.
- **Consequences**: A small learning curve; state must be managed carefully;
  provider upgrades occasionally need attention.

---

## ADR 002: AWS VPC + single public subnet for a simple web tier

- **Status**: Accepted
- **Decision**: One VPC (`10.0.0.0/16`) with one public subnet
  (`10.0.1.0/24`) in the first AZ.
- **Why**: The app is a single public-facing node. A public subnet with a route
  to the IGW is all that's needed; no private subnet/NAT is required.
- **Alternatives**: Default VPC, multiple AZs, private + public subnets with NAT.
- **Why not**:
  - Default VPC - shared, not isolated, encourages orphaned resources.
  - Private subnet + NAT gateway - extra cost (~$32+/mo) and complexity with no
    benefit for a single public node.
  - Multi-AZ - HA comes from running multiple instances; overkill for a demo.
- **Consequences**: No high availability or NAT cost. A production web tier
  should add a private app subnet, NAT, and multiple AZs.

---

## ADR 003: Key-based SSH + SSM Session Manager for access

- **Status**: Accepted
- **Decision**: SSH via an EC2 key pair (restricted to your IP) as primary
  access, plus SSM Session Manager (via the `AmazonSSMManagedInstanceCore`
  policy) as a keyless alternative.
- **Why**: SSH is the standard, familiar debugging path; SSM removes the need to
  expose port 22 at all and works when your IP changes.
- **Alternatives**: Password auth, key-only with open port 22, SSM-only.
- **Why not**: Password auth is insecure; open port 22 invites brute force;
  SSM-only loses the easy `scp` workflow some developers expect.
- **Consequences**: Keys must be stored privately (`chmod 400`, gitignored);
  SSM needs the SSM agent (preinstalled on Ubuntu AMIs) and outbound 443.

---

## ADR 004: user-data script (not Ansible) for bootstrapping

- **Status**: Accepted
- **Decision**: `user-data.sh` installs Docker + Nginx and configures the reverse
  proxy on first boot.
- **Why**: Zero extra tooling, no control node, runs automatically at launch,
  and is pure shell so it works from a plain Ubuntu AMI.
- **Alternatives**: Ansible/Puppet/Chef, Packer-built AMIs, Terraform
  provisioners (remote-exec).
- **Why not**:
  - Ansible - needs an inventory, SSH reachability at bootstrap, and a control
    node; heavy for one script.
  - Packer - excellent for golden AMIs but adds build complexity and slower
    iteration.
  - `remote-exec` provisioners - state-ordering pitfalls, discouraged by
    HashiCorp for general config.
- **Consequences**: A script that must stay idempotent and debuggable via logs;
  larger teams/apps should move to Packer images + Ansible/SSM documents.

---

## ADR 005: Separate security group for SSH

- **Status**: Accepted
- **Decision**: SSH ingress (port 22) is scoped to a single SG rule limited to
  `allowed_ssh_cidr` (your IP, default `your-ip/32`).
- **Why**: Least privilege - admin traffic is the highest-risk surface and
  should never be open to `0.0.0.0/0`.
- **Alternatives**: One broad rule allowing SSH from anywhere; separate
  management SG; AWS Systems Manager only.
- **Why not**: SSH from `0.0.0.0/0` is a classic brute-force target. A separate
  SG is fine but unnecessary for a single instance.
- **Consequences**: If your IP changes, SSH breaks until `allowed_ssh_cidr` is
  updated (mitigated by SSM).

---

## ADR 006: Local state (migrate to S3 backend in production)

- **Status**: Accepted for this project, with a documented migration path
- **Decision**: State is stored in `terraform.tfstate` locally.
- **Why**: Zero setup, no bucket to create, works offline - ideal for a demo.
- **Alternatives**: S3 + DynamoDB backend, Terraform Cloud/Enterprise.
- **Why not**: S3/DynamoDB need extra IAM + a bucket; Terraform Cloud is a
  separate account. Not warranted for a single-user demo.
- **Consequences**: No locking, no sharing, risk of losing state. **In
  production, move to an S3 backend with DynamoDB locking** - see
  `security.md`. The code is backend-agnostic, so migration is a few lines in
  `versions.tf` plus `terraform init -migrate-state`.

---

## ADR 007: EC2 (self-managed) vs managed services for the app

- **Status**: Accepted
- **Decision**: Run the app on an EC2 instance with Docker + Nginx.
- **Why**: Full control, exercises core AWS/DevOps skills (VPC, SG, IAM,
  user-data, Docker, reverse proxying), and demonstrates the architecture the
  project is about.
- **Alternatives**: ECS/Fargate, EKS, Elastic Beanstalk, Lambda.
- **Why not**: Managed services hide the underlying networking/bootstrap details
  this project teaches, need container registries/build pipelines, and (for EKS)
  add significant cost and ops burden.
- **Consequences**: You own patching and uptime. In production with autoscaling
  needs, move the container to Fargate/ECS behind an ALB.
