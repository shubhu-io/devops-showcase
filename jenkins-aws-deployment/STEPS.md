# Steps — jenkins-aws-deployment

Copy-paste execution.

## Prerequisites
- Docker, Node 18+
- For cloud: AWS account + EC2 key pair

## Clone
```bash
git clone https://github.com/shubhu-io/jenkins-aws-deployment.git
cd jenkins-aws-deployment
```

## Run Locally (no AWS)
```bash
cd app
docker build -t node-app:local .
docker run -d --name node-app -p 127.0.0.1:3000:3000 node-app:local
curl http://127.0.0.1:3000/health
PORT=34568 node --test
docker rm -f node-app
```

## Run via Jenkins to EC2
```bash
# 1. Launch EC2 with scripts/ec2-bootstrap.sh as User Data
# 2. In Jenkins set EC2_PUBLIC_IP and credential ec2-key (ubuntu + .pem)
# 3. Create Pipeline -> Jenkinsfile -> git push to trigger
curl http://<EC2_PUBLIC_IP>/health
```

## Cleanup
```bash
aws ec2 terminate-instances --instance-ids <id>
docker rm -f node-app
```

## Deploy Your Own App (3 changes)

**1. Use your GitHub repo:**
```bash
# fork https://github.com/shubhu-io/jenkins-aws-deployment
git clone https://github.com/<YOUR_USERNAME>/jenkins-aws-deployment.git
cd jenkins-aws-deployment
git remote set-url origin https://github.com/<YOUR_USERNAME>/jenkins-aws-deployment.git
```

**2. Replace the app + update deploy config:**
```bash
nano app/server.js
# in Jenkinsfile change:
# IMAGE_REPO = 'node-app' -> 'my-app'
# APP_PORT = '3000' (must match your app)
# and set Jenkins env EC2_PUBLIC_IP to your EC2 IP
```

**3. Update EC2 target:**
```bash
# in scripts/deploy.sh / nginx/app-proxy.conf, ensure proxy points to your APP_PORT
# then: git push -> Jenkins builds -> curl http://<YOUR_EC2_IP>/health
```
