# Steps — terraform-aws-infrastructure

Copy-paste execution.

## Prerequisites
- Terraform >=1.5, AWS CLI v2, AWS account configured (`aws configure`)
- Existing EC2 key pair in target region

## Clone
```bash
git clone https://github.com/shubhu-io/terraform-aws-infrastructure.git
cd terraform-aws-infrastructure
```

## Run
```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# edit: key_name and allowed_ssh_cidr=YOUR_IP/32
cd terraform
terraform init
terraform validate
terraform plan
terraform apply
curl http://$(terraform output -raw public_ip)/health
```

## Local Only
```bash
make local-test
# or: cd app && node server.js --selftest
```

## Cleanup
```bash
terraform destroy
```

## Deploy Your Own App (3 changes)

**1. Use your GitHub repo:**
```bash
# fork https://github.com/shubhu-io/terraform-aws-infrastructure
git clone https://github.com/<YOUR_USERNAME>/terraform-aws-infrastructure.git
cd terraform-aws-infrastructure
git remote set-url origin https://github.com/<YOUR_USERNAME>/terraform-aws-infrastructure.git
```

**2. Point Terraform to your container:**
```bash
nano terraform/terraform.tfvars
# set: key_name, allowed_ssh_cidr, app_image = "ghcr.io/<YOUR_USERNAME>/my-app:latest"
#      app_port = 3000, app_internal_port = 3000 (if your app listens on 3000)
# or build your app image and push to Docker Hub/GHCR first
```

**3. Deploy:** `terraform apply` → `curl http://$(terraform output -raw public_ip)/health`

