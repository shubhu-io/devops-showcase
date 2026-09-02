# Execution Steps — DevOps Portfolio (8 Standalone Projects)

> This file is separate from README.md. Copy-paste commands only. Each project runs alone.

## Prerequisites (install once)
```bash
git --version
docker --version
docker compose version
node --version   # 18+
terraform --version  # for terraform project only
aws --version        # for terraform/aws projects only
kubectl version --client  # for kubernetes only
ansible --version       # for ansible only
```

## Clone
```bash
# Portfolio (all 8)
git clone https://github.com/shubhu-io/devops-portfolio.git
cd devops-portfolio

# Or single repo (for interview)
git clone https://github.com/shubhu-io/linux-nginx-server.git
git clone https://github.com/shubhu-io/dockerized-web-application.git
git clone https://github.com/shubhu-io/jenkins-cicd-pipeline.git
git clone https://github.com/shubhu-io/jenkins-aws-deployment.git
git clone https://github.com/shubhu-io/terraform-aws-infrastructure.git
git clone https://github.com/shubhu-io/kubernetes-application-deployment.git
git clone https://github.com/shubhu-io/ansible-server-configuration.git
git clone https://github.com/shubhu-io/github-actions-cicd.git
```

---

### 1. linux-nginx-server (needs Ubuntu VM)
```bash
cd linux-nginx-server
sudo bash scripts/install-server.sh
sudo bash scripts/setup.sh
curl -I http://127.0.0.1/
bash tests/smoke-test.sh
```

### 2. dockerized-web-application
```bash
cd dockerized-web-application
cp .env.example .env
docker compose up -d --build
curl http://localhost/health
bash tests/test-api.sh
docker compose down
```

### 3. jenkins-cicd-pipeline
```bash
cd jenkins-cicd-pipeline
docker compose -f jenkins/docker-compose.yml up -d --build
bash scripts/run-pipeline.sh
# open http://localhost:8080 -> create Pipeline -> Jenkinsfile -> Build Now
# local test without Jenkins:
PORT=34567 node --test app/test/test.js
```

### 4. jenkins-aws-deployment
```bash
cd jenkins-aws-deployment/app
docker build -t node-app:local .
docker run -d --name node-app -p 127.0.0.1:3000:3000 node-app:local
curl http://127.0.0.1:3000/health
PORT=34568 node --test
docker rm -f node-app
```

### 5. terraform-aws-infrastructure
```bash
cd terraform-aws-infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: key_name + allowed_ssh_cidr
terraform init
terraform validate
terraform plan
terraform apply
curl http://$(terraform output -raw public_ip)/health
terraform destroy
```

### 6. kubernetes-application-deployment
```bash
cd kubernetes-application-deployment
kind create cluster --name demo
docker build -t ghcr.io/your-org/kubernetes-demo-app:1.0.0 ./app
kind load docker-image ghcr.io/your-org/kubernetes-demo-app:1.0.0 --name demo
bash scripts/deploy.sh
kubectl get pods -n demo-app
kubectl port-forward svc/demo-app -n demo-app 8080:80 &
curl http://localhost:8080/health
```

### 7. ansible-server-configuration
```bash
cd ansible-server-configuration
cp inventory/hosts.ini.example inventory/hosts.ini
ansible-galaxy collection install community.general
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
```

### 8. github-actions-cicd
```bash
cd github-actions-cicd
docker build -t app:ci ./app
bash scripts/healthcheck.sh
# push tag to trigger publish:
git tag v1.0.0 && git push origin v1.0.0
```

---

## Cleanup
```bash
docker compose down -v
kind delete cluster --name demo
kubectl delete -f k8s/ --ignore-not-found
terraform destroy
aws ec2 terminate-instances --instance-ids <id>
```

## Port 3000 Busy Fix
```bash
PORT=34567 node --test
```

---

## Deploy Your Own App — Where to Change Your GitHub Link

**For every repo (3 places):**

**1. Fork & point your system to your GitHub repo:**
```bash
# on GitHub: Fork https://github.com/shubhu-io/<repo> to https://github.com/<YOUR_USERNAME>/<repo>
git clone https://github.com/<YOUR_USERNAME>/<repo>.git
cd <repo>
# if you cloned the template directly, change the remote:
git remote set-url origin https://github.com/<YOUR_USERNAME>/<repo>.git
git remote -v
git push -u origin master   # or main
# check: gh repo view --json url  OR  git remote get-url origin
```

**2. Replace the demo app with yours:**
- `linux-nginx-server`: edit `web/index.html` and `nginx/hello-site.conf`
- `dockerized-web-application`: replace `app/server.js`, update `docker-compose.yml` image name, `cp .env.example .env`
- `jenkins-cicd-pipeline`: replace `app/`, update `Jenkinsfile` `APP_IMAGE = 'my-app'`, and `jenkins/.env.example` `GITHUB_REPO_URL`
- `jenkins-aws-deployment`: replace `app/`, update `Jenkinsfile` `IMAGE_REPO` and `APP_PORT`, update `EC2_PUBLIC_IP` in Jenkins
- `terraform-aws-infrastructure`: edit `terraform/terraform.tfvars` `app_image = "ghcr.io/<YOUR_USERNAME>/my-app:latest"` and `key_name`/`allowed_ssh_cidr`
- `kubernetes-application-deployment`: `docker build -t ghcr.io/<YOUR_USERNAME>/my-app:1.0.0 ./app && docker push ...` → update `k8s/deployment.yaml` `image: ghcr.io/<YOUR_USERNAME>/my-app:1.0.0`
- `ansible-server-configuration`: edit `inventory/hosts.ini` `ansible_host=<YOUR_IP>`, `playbooks/site.yml` vars, `roles/nginx/tasks/main.yml` inline HTML
- `github-actions-cicd`: replace `app/` — no image rename needed, `ghcr.io/${{ github.repository }}` auto-uses your new repo name; push tag `git tag v1.0.0 && git push origin v1.0.0` to publish

**3. Verify your link is active:**
```bash
git remote -v                          # should show YOUR_USERNAME
git log --oneline -1
curl -I https://raw.githubusercontent.com/<YOUR_USERNAME>/<repo>/master/README.md
# for GHCR:
docker pull ghcr.io/<YOUR_USERNAME>/<repo>:latest
```

> Tip: Keep `STEPS.md` in your fork — it already points to `shubhu-io`; replace with `<YOUR_USERNAME>` everywhere before first push. Each repo's own `STEPS.md` has the exact 3 changes for that stack.
