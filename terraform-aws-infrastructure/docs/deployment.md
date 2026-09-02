# Deployment

End-to-end walkthrough: apply, verify, update, destroy. The whole stack is
created from `terraform/` with a single `terraform apply`.

## 1. First deployment

From the project root:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars   # then fill it in
cd terraform
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

Typing `yes` at the prompt starts creation. Expected flow and outputs:

```
aws_vpc.main: Creating...
aws_iam_role.ec2: Creating...
aws_subnet.public: Creating...
aws_security_group.web: Creating...
aws_internet_gateway.main: Creating...
aws_route_table.public: Creating...
aws_route_table_association.public: Creating...
aws_instance.web[0]: Creating...          # EC2 is slowest (provisioning + status checks)
aws_instance.web[0]: Still creating... [40s elapsed]

Apply complete! Resources: 8 added, 0 changed, 0 destroyed.

Outputs:

instance_id = "i-0abcd1234efgh5678"
public_dns  = "ec2-52-90-123-45.compute-1.amazonaws.com"
public_ip   = "52.90.123.45"
ssh_command = "ssh -i ~/.ssh/terraform-demo.pem ubuntu@ec2-52-90-123-45.compute-1.amazonaws.com"
```

## 2. Verify the deployment

```bash
# From the terraform/ directory
terraform output

# The app needs ~1-2 min after apply for user-data to finish.
curl http://$(terraform output -raw public_ip)
curl http://$(terraform output -raw public_ip)/health
```

- `curl /` → the HTML app page.
- `curl /health` → `{"status":"ok","uptime":...,"timestamp":"..."}`.
- `terraform output -raw public_ip` feeds the public IP into curl.

Console checks: EC2 → Instances → the `terraform-aws-docker-dev-web-1`
instance shows `2/2 status checks passed` and `IPv4 public IP` set.

## 3. Updating the stack (e.g. change user-data)

1. Edit `terraform/user-data.sh` (say, change the container image or nginx
   config).
2. `terraform plan` → you should see
   `aws_instance.web[0] will be updated (or replaced)` - replacement happens
   because `user_data_replace_on_change = true`.
3. `terraform apply` → old instance is terminated, a new one launches and runs
   the new bootstrap.
4. Re-verify with the curl commands (the public IP will change).

To change non-bootstrap things - instance type, AMI, VPC CIDR, SG rules - edit
`variables.tf` or `terraform.tfvars`, then plan → apply. `terraform apply` only
touches what differs.

## 4. Tearing everything down

```bash
terraform destroy          # review the plan, type "yes"
```

Expected:

```
aws_route_table_association.public: Destroying...
aws_instance.web[0]: Destroying... [40s]
aws_security_group.web: Destroying...
aws_vpc.main: Destroying...

Destroy complete! Resources: 8 destroyed.
```

## 5. Confirm cleanup

```bash
aws ec2 describe-instances --region us-east-1 \
  --filters "Name=tag:Project,Values=terraform-aws-docker" \
  --query "Reservations[].Instances[].[InstanceId,State.Name]"
```

Empty list = clean. Double-check the VPC is gone in the console (VPC →
Your VPCs). **Important:** `terraform destroy` only removes what Terraform
manages. The key pair in `~/.ssh/` and your `~/.aws/credentials` are untouched
(and should be).

## 6. Common deployment pitfalls

- **Apply succeeds but curl fails** → user-data still running; wait and check
  `/tmp/user-data-complete.log` via SSH (see `troubleshooting.md` §6).
- **Plan shows unexpected changes** → drift; see `troubleshooting.md` §8.
- **Destroy hangs** → an unmanaged dependency; see `troubleshooting.md` §13.
