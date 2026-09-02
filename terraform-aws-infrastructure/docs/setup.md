# Setup

How to go from a blank machine to a running AWS stack. Run these from the
project root (`terraform-aws-infrastructure/`).

## 1. Prerequisites

- **Terraform** >= 1.5 (validated with 1.14.9). Install from
  https://developer.hashicorp.com/terraform/install or `brew install terraform`.
  Check: `terraform --version`.
- **AWS CLI** v2. Check: `aws --version`.
- **Node.js** >= 18 (only needed to test the app locally, optional).
- **Docker** (only needed for the local run option, optional).
- An **AWS account** with an IAM user that can create VPC/EC2/IAM resources.

## 2. Configure AWS credentials

```bash
aws configure
```

Enter your access key ID, secret key, region (`us-east-1`), and output
(`json`). Verify with:

```bash
aws sts get-caller-identity
```

Your IAM user needs at least: `AmazonEC2FullAccess`, `AmazonVPCFullAccess`,
`AmazonS3ReadOnlyAccess`, `AmazonSSMFullAccess`, and `IAMFullAccess`
(`iam:CreateRole`, `iam:PassRole`). For learning, an `AdministratorAccess` user
is fine but remember least privilege for anything real.

## 3. Create an EC2 key pair

Key pairs are **region-specific** - create it in the region you'll deploy to.

```bash
aws ec2 create-key-pair \
  --key-name terraform-demo \
  --key-type ed25519 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/terraform-demo.pem
```

On Linux/macOS: `chmod 400 ~/.ssh/terraform-demo.pem`.
On Windows: the same command stores the file in `%USERPROFILE%\.ssh\`.

## 4. Find your public IP (for SSH lockdown)

```bash
curl ifconfig.me
```

Note it as `<your-ip>/32`, e.g. `203.0.113.5/32`.

## 5. Create terraform.tfvars

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars`:

```hcl
region            = "us-east-1"
key_name          = "terraform-demo"
allowed_ssh_cidr  = "203.0.113.5/32"   # your real IP with /32
```

## 6. Initialize, format, validate

```bash
cd terraform
terraform init          # downloads the AWS provider (needs network)
terraform fmt -recursive
terraform validate
```

Expected:
```
Terraform has been successfully initialized!
Success! The configuration is valid.
```

## 7. Plan and apply

```bash
terraform plan
terraform apply          # type "yes" when prompted
```

Expected (abridged):

```
aws_instance.web[0]: Creating...
aws_instance.web[0]: Still creating... [10s elapsed]
...
Apply complete! Resources: 8 added, 0 changed, 0 destroyed.

Outputs:
instance_id = "i-0abcd1234efgh5678"
public_ip   = "52.90.123.45"
```

## 8. Verify

```bash
curl http://$(terraform output -raw public_ip)   # app HTML
curl http://$(terraform output -raw public_ip)/health   # {"status":"ok",...}
```

Wait 1-2 minutes after apply for user-data to finish installing Docker + Nginx.

## 9. Optional: SSH in

```bash
terraform output        # copy the ssh_command value
ssh -i ~/.ssh/terraform-demo.pem ubuntu@<public_ip>
sudo cat /tmp/user-data-complete.log
```

## 10. When done

```bash
terraform destroy       # type "yes"
```

Terminate everything so you don't get billed.

## Troubleshooting

Credentials, SSH timeouts, user-data not running, capacity errors... see
[`troubleshooting.md`](./troubleshooting.md).
