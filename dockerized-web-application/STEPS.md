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
