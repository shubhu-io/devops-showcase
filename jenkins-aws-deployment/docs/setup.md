# Setup Guide

Goal: stand up the full pipeline — AWS account, EC2 host, and a Jenkins job that
deploys the app. Everything here is real, runnable steps.

> ⚠️ **COST WARNING** — EC2 instances bill by the second while running. A `t2.micro`
> is free-tier eligible, but once free-tier hours run out you pay ~$8.50/month.
> **Terminate instances after testing** (see [Cost Considerations](../README.md#-cost-considerations)).

---

## 1. Prerequisites

- **AWS account** with an IAM user that has (least-privilege) `AmazonEC2FullAccess`
  or the specific run/stop/terminate/describe permissions.
- **AWS CLI** installed and configured: `aws configure` (region `us-east-1`).
- **Node.js ≥ 18** and **Docker** on your local machine (for the LOCAL TEST path).
- **Java 17** to run the local Jenkins (or any machine that will run Jenkins).
- A **GitHub repository** containing this project folder's files.

## 2. Create an EC2 key pair

```bash
aws ec2 create-key-pair --key-name devops-key --query 'KeyMaterial' --output text > ~/.ssh/devops-key.pem
chmod 400 ~/.ssh/devops-key.pem
```

Notes:
- The private key is shown **once**; store it in `~/.ssh/` and never commit it.
- If you create it in the AWS console instead, you download a `.pem` file.
- The key name must match what you pass to `run-instances`.

## 3. Create a security group (least privilege)

```bash
SG_ID=$(aws ec2 create-security-group \
  --group-name devops-sg \
  --description "DevOps project: 22 from my IP, 80 from anywhere" \
  --query 'GroupId' --output text)

# Allow SSH only from YOUR public IP (recommended over 0.0.0.0/0)
MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 22 --cidr "${MY_IP}/32"

# Allow HTTP from anywhere (public web app)
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 80 --cidr 0.0.0.0/0

echo "Security group: $SG_ID"
```

Rules summary:

| Port | Protocol | Source | Purpose |
|---|---|---|---|
| 22 | TCP | `YOUR_IP/32` | SSH admin (never `0.0.0.0/0` if avoidable) |
| 80 | TCP | `0.0.0.0/0` | Public HTTP traffic to Nginx |

## 4. Launch the EC2 instance with user-data bootstrap

Get an Ubuntu 24.04 AMI ID, then launch:

```bash
AMI_ID=$(aws ec2 describe-images --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
  "Name=state,Values=available" --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text)

aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t2.micro \
  --key-name devops-key \
  --security-group-ids "$SG_ID" \
  --user-data file://scripts/ec2-bootstrap.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=devops-node-app}]'
```

Wait for it to boot and grab the public IP:

```bash
aws ec2 describe-instances \
  --filters Name=tag:Name,Values=devops-node-app \
  --query 'Reservations[].Instances[].{State:State.Name,PublicIp:PublicIpAddress}' --output table
```

Verify the bootstrap finished (Docker installed):

```bash
ssh -i ~/.ssh/devops-key.pem ubuntu@EC2_IP 'cat /opt/devops/bootstrap-done && docker --version'
```

## 5. Install Jenkins

**Option A — on your local machine (used in this project):**

```bash
# Debian/Ubuntu
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update && sudo apt-get install -y jenkins
sudo systemctl enable --now jenkins
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Windows: run Jenkins via the official `.msi`/`.war` (`java -jar jenkins.war`) or
use Docker: `docker run -d --name jenkins -p 8080:8080 jenkins/jenkins:lts`.

**Option B — on the EC2 host** (see docs/architecture-decisions.md "Jenkins on
separate host vs on EC2"). If you choose this, port 8080 must be added to the
security group.

Open `http://JENKINS_HOST:8080`, complete the unlock wizard with the initial
admin password, and install the suggested plugins (Pipeline, Git, SSH Agent,
Credentials Binding).

## 6. Configure Jenkins

### 6.1 Global environment variable

`Manage Jenkins → System → Global properties → Environment variables`:

| Key | Value |
|---|---|
| `EC2_PUBLIC_IP` | the public IP from step 4 |

The Jenkinsfile reads `EC2_PUBLIC_IP` from params first, then this env var.

### 6.2 SSH key credential (`ec2-key`)

`Manage Jenkins → Credentials → System → Global credentials → Add credentials`:

- Kind: **SSH Username with private key**
- ID: `ec2-key` ← **must match the Jenkinsfile's `sshagent(['ec2-key'])`**
- Username: `ubuntu`
- Private key: paste the contents of `~/.ssh/devops-key.pem`
- Description: "SSH key to the EC2 deploy host"

> The key is encrypted in Jenkins' credential store — never in the repo.

### 6.3 Git credential (for the job checkout)

Add a **Username with password** (or token) credential with ID `github-creds`
pointing at your GitHub account, or use Jenkins' built-in GitHub plugin handling.
Select it in the job's "Git" SCM config.

### 6.4 (Optional) Docker registry credential

If you set `USE_REGISTRY=true` in the Jenkinsfile, add a **Username with password**
credential with ID `dockerhub` for `docker login`.

## 7. Create the pipeline job

1. `New Item → name: devops-node-app → Pipeline`.
2. **General** → ☑ *GitHub project* → your repo URL.
3. **Build Triggers** → ☑ *GitHub hook trigger for GITScm polling* (and/or
   *Poll SCM* `H/5 * * * *` as a fallback when no webhook).
4. **Pipeline** → Definition: *Pipeline script from SCM* → SCM: *Git* →
   Repository URL (your GitHub), Credentials (`github-creds`), Branch
   `*/main`, Script Path `Jenkinsfile`.
5. Save, then run **Build Now** once to validate the pipeline wiring.

## 8. Configure Nginx on EC2 (once)

The deploy script starts the container on `127.0.0.1:3000`. Install Nginx and
enable the proxy config:

```bash
ssh -i ~/.ssh/devops-key.pem ubuntu@EC2_IP
sudo apt-get install -y nginx
# copy this repo's nginx/app-proxy.conf to the host, then:
sudo cp app-proxy.conf /etc/nginx/conf.d/app-proxy.conf
sudo nginx -t
sudo systemctl reload nginx
```

> Alternative one-liner over SSH:
> `scp nginx/app-proxy.conf ubuntu@EC2_IP:/tmp/ && ssh ubuntu@EC2_IP 'sudo cp /tmp/app-proxy.conf /etc/nginx/conf.d/ && sudo nginx -t && sudo systemctl reload nginx'`

## 9. First end-to-end run

1. `git add . && git commit -m "Initial pipeline" && git push`.
2. Watch the job in Jenkins/Blue Ocean — stages: Checkout → Test → Docker Build →
   Security Scan → Transfer Image to EC2 → Deploy to EC2 → Health Check.
3. Open `http://EC2_IP/` in a browser → you should see the app page with the build
   number.
4. `curl http://EC2_IP/health` → `{"status":"ok", ...}`.

## 10. LOCAL TEST vs AWS DEPLOYMENT

| | LOCAL TEST | AWS DEPLOYMENT |
|---|---|---|
| Where | Your machine | EC2 public IP |
| How | `docker build ./app` then `docker run -p 3000:3000 node-app:local` | Full Jenkins pipeline (image transfer + remote run + health check) |
| Ports | 3000 (or `-p 80:3000`) | 80 (Nginx) → 3000 (container) |
| No AWS needed | Yes | No — requires account, key pair, SG, instance |

## Troubleshooting early setup

- **SSH timeout** → security group 22 rule missing or wrong source IP.
- **`Permission denied (publickey)`** → wrong key, or `.pem` perms too open
  (`chmod 400`).
- **Bootstrap never finished** → check `/var/log/cloud-init-output.log` on the host
  for the user-data script's errors.

See [docs/troubleshooting.md](troubleshooting.md) for the full matrix.
