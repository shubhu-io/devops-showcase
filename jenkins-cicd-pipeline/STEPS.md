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

## Deploy Your Own App (3 changes)

**1. Use your GitHub repo:**
```bash
# fork https://github.com/shubhu-io/jenkins-cicd-pipeline
git clone https://github.com/<YOUR_USERNAME>/jenkins-cicd-pipeline.git
cd jenkins-cicd-pipeline
git remote set-url origin https://github.com/<YOUR_USERNAME>/jenkins-cicd-pipeline.git
```

**2. Replace the app and update Jenkins config:**
```bash
# put your app in app/ (keep server.js port 3000 or update HEALTHCHECK)
nano app/server.js
# optional: change image name in Jenkinsfile
# APP_IMAGE = 'hello-app' -> 'my-app'
# and in .env.example: JENKINS_ADMIN_PASSWORD, GITHUB_REPO_URL
nano Jenkinsfile
```

**3. In Jenkins:** Manage Jenkins → Credentials → update `github-creds` to your PAT, create Pipeline job pointing to `https://github.com/<YOUR_USERNAME>/jenkins-cicd-pipeline.git` (Script Path `Jenkinsfile`) → Build Now

