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
