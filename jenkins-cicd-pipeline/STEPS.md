# Steps — jenkins-cicd-pipeline

Copy-paste execution.

## Prerequisites
- Docker 24+ with Compose v2
- Git, ~2GB RAM free

## Clone
```bash
git clone https://github.com/shubhu-io/jenkins-cicd-pipeline.git
cd jenkins-cicd-pipeline
```

## Run
```bash
docker compose -f jenkins/docker-compose.yml up -d --build
bash scripts/run-pipeline.sh
# open http://localhost:8080
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
# create Pipeline job -> point to this repo -> Script Path Jenkinsfile -> Build Now
```

## Verify Locally (no Jenkins)
```bash
PORT=34567 node --test app/test/test.js
curl http://localhost:8091/health
```

## Cleanup
```bash
docker compose -f jenkins/docker-compose.yml down -v
```
