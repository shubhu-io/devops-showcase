# Terraform - AWS + EC2 + Docker + Nginx

Terraform configuration that provisions a complete single-node web stack:

- **VPC** (`10.0.0.0/16`) with an **Internet Gateway** and a public route table
- One **public subnet** (`10.0.1.0/24`) in the first AZ
- A **security group** (SSH from your IP only, HTTP/HTTPS from anywhere)
- **IAM** role + instance profile (SSM managed policy + minimal S3 read)
- An **EC2** instance running Ubuntu 24.04 LTS (latest AMI fetched via `aws_ami`)
- **user-data.sh** bootstrap: installs Docker + Nginx, runs the app container, configures Nginx as a reverse proxy to `localhost:3000`

```
Internet → VPC → Public Subnet → EC2 → Docker → Nginx → App (port 3000)
```

## Quick usage

```bash
# 1. Copy the example vars and fill in real values (key_name, allowed_ssh_cidr)
cp terraform.tfvars.example terraform.tfvars

# 2. Init (downloads the AWS provider)
terraform init

# 3. Format + validate
terraform fmt -recursive
terraform validate

# 4. Review the plan
terraform plan

# 5. Apply (type "yes" or add -auto-approve)
terraform apply

# 6. See outputs
terraform output

# 7. Test the app
curl http://$(terraform output -raw public_ip)

# 8. Tear everything down
terraform destroy
```

## Files

| File | Purpose |
|------|---------|
| `provider.tf` | AWS provider, region, `default_tags` |
| `versions.tf` | Terraform + provider version constraints |
| `variables.tf` | All tunable inputs with defaults |
| `vpc.tf` | VPC, Internet Gateway, route table + association |
| `subnet.tf` | Public subnet with auto public IP |
| `security-group.tf` | Ingress/egress rules (least privilege) |
| `iam.tf` | EC2 role, SSM attachment, minimal S3 inline policy |
| `ec2.tf` | `aws_ami`/AZ data sources + `aws_instance` |
| `user-data.sh` | EC2 bootstrap script (Docker + Nginx) |
| `outputs.tf` | instance_id, public_ip, public_dns, ssh_command |

## ⚠️ Cost warning

Every resource here is billable. `t2.micro` / `t3.micro` are *often* free-tier
eligible but that is **not guaranteed** and only applies to one month of usage.
**Always run `terraform destroy` when you are done.** A forgotten instance
billing its own VPC/route table is cheap, but the EC2 hours add up.

## State

State is stored **locally** in `terraform.tfstate`. For any real production use,
migrate to a remote backend (e.g. S3 + DynamoDB locking) - see
`../docs/architecture-decisions.md`.
