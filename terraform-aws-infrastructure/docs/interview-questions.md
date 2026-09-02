# Interview Questions & Answers

Short, accurate answers to questions you might get about this project. Use the
"Say more" line to go deeper if the interviewer asks follow-ups.

---

### Q1. What is Infrastructure as Code (IaC)?

**A.** IaC is managing and provisioning infrastructure (VMs, networks, IAM,
etc.) through declarative or programmatic definitions in code, instead of
clicking through a console. Here, `*.tf` files define the whole AWS stack, so it
is reproducible, version-controlled, reviewable, and can be applied by CI/CD.

- **Say more**: Declarative (you state the desired end state, e.g. Terraform) vs
  imperative (you script the steps, e.g. AWS CLI). IaC enables consistent
  environments across dev/staging/prod.

---

### Q2. Why Terraform instead of CloudFormation?

**A.** Terraform is cloud-agnostic (works with AWS, GCP, Azure...), uses HCL
which is more readable than CloudFormation's JSON/YAML, has a large module
ecosystem, and does not require AWS. CloudFormation is AWS-only but deeply
integrated and has native rollback/stack features.

- **Say more**: Both are declarative. Terraform's real advantage is portability
  and community; CloudFormation's is tighter AWS integration (and being free of
  extra tooling). For a demo on AWS, either works.

---

### Q3. What is Terraform state?

**A.** State is a file (`terraform.tfstate`) that maps your declared resources to
real-world infrastructure (IDs, attributes). Terraform reads it during
plan/apply to compute diffs and to know what it owns. It also stores metadata
for data that cannot be derived from config alone.

- **Say more**: Because Terraform asks the cloud "does X exist?" through state,
  it can't work well without it. That's why losing/corrupting state is a big
  deal.

---

### Q4. Where should state live in production, and why?

**A.** In a **remote backend** - typically S3 for storage plus DynamoDB for
locking. Why: team collaboration (everyone uses the same state), locking (no
two people apply at once), backup/versioning, and it survives a wiped laptop.
Local state is fine for a single-user demo only.

- **Say more**: `backend "s3" { bucket = "..." key = "..." region = "..." }`
  with `dynamodb_table = "..."`. Terraform writes state and takes a lock for the
  duration of apply.

---

### Q5. What's the difference between `terraform plan` and `terraform apply`?

**A.** `plan` computes a diff between the desired state (config) and the current
state, showing exactly what will be added/changed/destroyed, and makes **no**
changes. `apply` executes that diff against the real infrastructure (and, by
default, re-runs a plan internally before asking for confirmation).

- **Say more**: Plan is the "dry run / code review" step; apply is the
  "do it" step. The output `Plan: N to add, M to change, K to destroy` summarizes
  the risk.

---

### Q6. What is drift and how do you detect it?

**A.** Drift is when real infrastructure no longer matches the configuration
(when someone edits a resource in the AWS console). You detect it by running
`terraform plan` - if it proposes changes you didn't intentionally make, that's
drift. `terraform refresh` updates state to match reality.

- **Say more**: You can also compare state attributes (`terraform state show`)
  with the console. The fix is either reverting the console change or importing
  it so Terraform manages it.

---

### Q7. Why do we need a VPC, subnets, and an Internet Gateway?

**A.** A VPC gives you an isolated, private network with your own IP ranges.
Subnets divide it into segments (public vs private) with different access
profiles. The Internet Gateway connects the VPC to the internet so resources in
the public subnet can be reached (and reach out). Without them AWS resources
have no network boundary or internet path.

- **Say more**: In this project: VPC `10.0.0.0/16`, one public subnet, a route
  table entry `0.0.0.0/0 → IGW`, and the subnet associated to that route table.

---

### Q8. Why security groups?

**A.** Security groups are instance-level virtual firewalls that filter traffic
in/out of EC2 instances by protocol, port, and source CIDR. We allow 22 from
your IP only, 80/443 from anywhere, and block everything else. They protect the
instance from unwanted traffic without modifying the OS.

- **Say more**: Stateful (a reply is automatically allowed), attach directly to
  instances, and are evaluated before the instance receives traffic. Least
  privilege: only the ports the app needs are open.

---

### Q9. Why IAM roles instead of access keys on the instance?

**A.** IAM roles give the instance short-lived, automatically rotated temporary
credentials via STS - no long-lived access keys sitting in files or env vars.
Keys can be stolen from disk; a role's credentials are scoped, expiring, and
revocable. We also scope the role to only SSM + a single S3 read (least
privilege).

- **Say more**: The instance profile (`aws_iam_instance_profile`) hands the
  role to the EC2 metadata service. This is why no credentials are baked into
  `user-data.sh`.

---

### Q10. How does `user-data` work?

**A.** User-data is a script/cloud-init config you pass at instance launch.
On first boot, cloud-init (preinstalled on Ubuntu AMIs) runs it as root and
writes output to `/var/log/cloud-init-output.log`. Here it installs Docker +
Nginx, runs the app container, and configures the Nginx reverse proxy.

- **Say more**: Terraform sends it via `user_data` (base64) and
  `user_data_replace_on_change = true` forces a fresh run when the script
  changes. `cloud-final` is the service that executes it; logs diagnose
  failures (`docs/troubleshooting.md`).

---

### Q11. What are the dangers of `terraform destroy`?

**A.** It deletes **all** managed resources non-selectively - the instance,
subnet, VPC, IAM role, everything. If other things depend on them (a database
you thought was separate, a load balancer, external users hitting the IP) they
break. Real AWS costs still apply for anything not managed by Terraform.

- **Say more**: Always inspect the plan first; never `destroy` a prod stack
  casually. Unmanaged resources (a DB you made by hand) survive destroy and keep
  billing you - so destroy doesn't mean "free AWS account".

---

### Q12. How do you handle secrets in Terraform?

**A.** Never put secrets in `.tf` files or `terraform.tfvars` (both gitignored).
Secrets go into AWS SSM Parameter Store or Secrets Manager, fetched with
`data "aws_ssm_parameter"`; sensitive variables use `sensitive = true` and
`variable` values can come from env vars / CI secrets. Keys are not committed
(`*.pem` is gitignored).

- **Say more**: State can contain sensitive values, so remote state must be
  encrypted (S3 SSE) and access-controlled. Use `sensitive` on outputs so
  Terraform masks them in plan/apply output.

---

### Q13. What is idempotency in Terraform?

**A.** Running the same configuration multiple times produces the same end
state - apply #2 with no changes makes no changes ("0 to add, 0 to change, 0 to
destroy"). Terraform achieves this by comparing desired vs actual state and
only acting on the diff, so scripts can be re-run safely.

- **Say more**: The equivalent in `user-data.sh` is writing idempotent commands
  (e.g. `ln -sf`, `rm -f` before symlink, `nginx -t` before reload) so a rerun
  doesn't break the box.

---

### Q14. How do you structure a Terraform project?

**A.** Split by resource domain: `provider.tf` / `versions.tf` for provider and
version constraints, `variables.tf` for inputs, `vpc.tf`, `subnet.tf`,
`security-group.tf`, `iam.tf`, `ec2.tf` for resources, `outputs.tf` for values,
`user-data.sh` for bootstrap, and `terraform.tfvars.example` as a template.
For bigger projects: remote state per environment, workspaces or separate dirs,
and reusable modules.

- **Say more**: Keep name/value tagging via `default_tags`, use a consistent
  `${project_name}-${environment}-<resource>` naming, and keep secrets out of
  the tree.

---

### Q15. What does `terraform fmt` do?

**A.** It formats HCL files to the canonical Terraform style - consistent
indentation, alignment of `=` signs, blank lines, and line wrapping - without
changing semantics. `terraform fmt -recursive` formats every `.tf` file in the
directory tree; `-check` only verifies (useful in CI).

- **Say more**: It's the equivalent of `prettier`/`gofmt` for Terraform.
  Standardized formatting makes diffs smaller and code review easier.
