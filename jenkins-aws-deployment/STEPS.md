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
