# Steps — dockerized-web-application

Copy-paste execution.

## Prerequisites
- Docker 24+ with Compose v2
- Git, Bash

## Clone
```bash
git clone https://github.com/shubhu-io/dockerized-web-application.git
cd dockerized-web-application
```

## Run
```bash
cp .env.example .env
docker compose up -d --build
docker compose ps
curl http://localhost/health
bash tests/test-api.sh
```

## Cleanup
```bash
docker compose down
docker compose down -v   # to delete database volume
```

## Deploy Your Own App (3 changes)

**1. Use your GitHub repo:**
```bash
# fork https://github.com/shubhu-io/dockerized-web-application
git clone https://github.com/<YOUR_USERNAME>/dockerized-web-application.git
cd dockerized-web-application
git remote set-url origin https://github.com/<YOUR_USERNAME>/dockerized-web-application.git
```

**2. Replace the demo app:**
```bash
# edit app/server.js or replace whole app/ folder with your code
nano app/server.js
# optional: change image name in docker-compose.yml
# image: dockerized-app:latest -> image: <YOUR_DOCKERHUB_USER>/my-app:latest
```

**3. Configure and run:**
```bash
cp .env.example .env && nano .env   # set DB_PASSWORD
docker compose up -d --build
```
