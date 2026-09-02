# Screenshots

This folder intentionally contains **no images**. The project was authored and
documented without a running Docker daemon on the authoring machine, so no real
screenshots could be captured. Screenshots below are **documented as commands
to run**, not as existing artifacts. When you run the stack yourself, capture
the outputs and drop the PNG files here.

## How to capture

| # | What to screenshot | Command |
|---|--------------------|---------|
| 1 | `docker build` output (multi-stage layers) | `docker compose build app` |
| 2 | Running services + status | `docker compose ps` |
| 3 | Local images with sizes | `docker images` |
| 4 | App container logs | `docker compose logs --tail=30 app` |
| 5 | `/health` JSON response | `curl -sS http://localhost/health` |
| 6 | `/api/message` JSON response | `curl -sS http://localhost/api/message` |
| 7 | HTML page in a browser | open `http://localhost` in Chrome/Firefox |
| 8 | Custom network details | `docker network inspect appnet` |
| 9 | Named volume details | `docker volume inspect dockerized-web-application_pgdata` |
| 10 | Health state from inspect | `docker inspect app-node --format '{{json .State.Health}}'` |

## Rules

- Never commit fabricated or copied screenshots. Each PNG must be a real
  capture taken from your own terminal/browser.
- Add a caption line under each image naming the command used.
