# Commands Cheat Sheet

> **Validation note:** These commands are **documented**, not executed during
> authoring (no Docker daemon on the authoring machine). Every flag and output
> shown is the standard behavior of the listed Docker/Docker Compose commands.

## 1. `docker --version`
↓ PURPOSE — Verify the Docker client is installed and see its version.
↓ WHAT IT DOES — Prints the client and (if reachable) the engine version.
↓ EXPECTED OUTPUT — `Docker version 29.x.x, build <hash>` or similar.
↓ COMMON ERROR — `docker: command not found`.
↓ FIX — Install Docker Desktop (Windows/macOS) or the `docker-ce` package, then reopen the shell.

## 2. `docker build -t dockerized-app:latest ./app`
↓ PURPOSE — Build an image from the app's Dockerfile and tag it.
↓ WHAT IT DOES — Sends the `./app` build context, executes each Dockerfile stage, caches layers, and tags the result.
↓ EXPECTED OUTPUT — Steps `[1/8]` … `[8/8]`, ending with `DONE ... dockerized-app:latest`.
↓ COMMON ERROR — `Error response from daemon: cannot delete container ... volume is in use` or a failed `RUN node --check`.
↓ FIX — Stop/remove the running container first, or fix the failing build step; rebuild with `--no-cache` if caching misleads you.

## 3. `docker images`
↓ PURPOSE — List local images.
↓ WHAT IT DOES — Shows `REPOSITORY`, `TAG`, `IMAGE ID`, `CREATED`, `SIZE`.
↓ EXPECTED OUTPUT — A table including `dockerized-app latest <id> ...`.
↓ COMMON ERROR — Empty list.
↓ FIX — You have not built/ pulled anything yet; run `docker compose build` or `docker pull nginx:alpine`.

## 4. `docker run -d -p 3000:3000 --name app-test --env PORT=3000 -v testvol:/data --network appnet dockerized-app:latest`
↓ PURPOSE — Start a container from an image with runtime config (detached, port mapping, name, env, volume, network).
↓ WHAT IT DOES — Creates and starts a container; `-d` detaches, `-p` publishes ports, `--name` names it, `--env` sets variables, `-v` mounts a volume, `--network` joins a network.
↓ EXPECTED OUTPUT — A container ID (long hex string) printed.
↓ COMMON ERROR — `docker: network appnet not found` or `port is already allocated`.
↓ FIX — Create the network with `docker network create appnet`, or free the port (see `docker ps` and troubleshooting).

## 5. `docker ps`
↓ PURPOSE — List running containers.
↓ WHAT IT DOES — Prints `CONTAINER ID`, `IMAGE`, `COMMAND`, `STATUS`, `PORTS`, `NAMES`.
↓ EXPECTED OUTPUT — 3 rows for `app-nginx`, `app-node`, `app-db` when the stack is up.
↓ COMMON ERROR — Nothing listed.
↓ FIX — The stack is down; run `docker compose up -d` or check with `docker ps -a`.

## 6. `docker ps -a`
↓ PURPOSE — List all containers, including stopped/exited ones.
↓ WHAT IT DOES — Adds stopped containers, useful to see why one exited.
↓ EXPECTED OUTPUT — Rows with `Exited (1) ...` for crashed containers.
↓ COMMON ERROR — None (always succeeds).
↓ FIX — Inspect an exited container with `docker logs <name>`.

## 7. `docker logs app-node`
↓ PURPOSE — View stdout/stderr of a container.
↓ WHAT IT DOES — Streams the captured logs; `-f` follows, `--tail 30` limits lines.
↓ EXPECTED OUTPUT — `[server] listening on port 3000`.
↓ COMMON ERROR — `Error: No such container: app-node`.
↓ FIX — Confirm the name with `docker ps -a` and use the exact container name/ID.

## 8. `docker exec -it app-node sh`
↓ PURPOSE — Open an interactive shell inside a running container.
↓ WHAT IT DOES — Runs `/bin/sh` inside the container for debugging.
↓ EXPECTED OUTPUT — A shell prompt like `/app #`.
↓ COMMON ERROR — `the input device is not a TTY`.
↓ FIX — Drop `-t` (`docker exec -i app-node sh`) or run from a real terminal.

## 9. `docker network ls`
↓ PURPOSE — List Docker networks.
↓ WHAT IT DOES — Shows `NETWORK ID`, `NAME`, `DRIVER`, `SCOPE`.
↓ EXPECTED OUTPUT — Rows including `appnet bridge local`.
↓ COMMON ERROR — `appnet` missing.
↓ FIX — Compose creates it automatically; if absent, `docker compose up -d` again or create manually with `docker network create appnet`.

## 10. `docker network create appnet`
↓ PURPOSE — Manually create a custom bridge network.
↓ WHAT IT DOES — Creates an isolated bridge network for container-to-container DNS.
↓ EXPECTED OUTPUT — A network ID hex string.
↓ COMMON ERROR — `network with name appnet already exists`.
↓ FIX — Reuse the existing one (`docker network inspect appnet`) or remove it first.

## 11. `docker volume ls`
↓ PURPOSE — List named volumes.
↓ WHAT IT DOES — Shows `DRIVER` and `VOLUME NAME`, e.g. `dockerized-web-application_pgdata`.
↓ EXPECTED OUTPUT — A row for `pgdata` after `docker compose up`.
↓ COMMON ERROR — Empty list / no pgdata volume.
↓ FIX — Start the stack once with `docker compose up -d` so the volume is created.

## 12. `docker compose up -d --build`
↓ PURPOSE — Build and start all services in the background.
↓ WHAT IT DOES — Rebuilds images where Dockerfiles changed, then creates networks/volumes and starts containers.
↓ EXPECTED OUTPUT — `Container app-db Created ...`, ending `Started`, then `docker compose ps` shows healthy.
↓ COMMON ERROR — `pull access denied for postgres:16-alpine` (typo/image not found).
↓ FIX — Check the tag spelling; `postgres:16-alpine` must exist on Docker Hub.

## 13. `docker compose ps`
↓ PURPOSE — Show the status of compose services.
↓ WHAT IT DOES — Lists service, container status, and health (with `--health`).
↓ EXPECTED OUTPUT — `app-node ... Up (healthy)`, `app-db ... Up (healthy)`, `app-nginx ... Up`.
↓ COMMON ERROR — `no such service` (stale file path).
↓ FIX — Run from the folder containing `docker-compose.yml`.

## 14. `docker compose down -v`
↓ PURPOSE — Stop and remove containers, networks, and named volumes.
↓ WHAT IT DOES — Removes everything including `pgdata`; **data is deleted**.
↓ EXPECTED OUTPUT — `Removing container app-db ... done`, `Removing network ... appnet`.
↓ COMMON ERROR — None, but it is destructive.
↓ FIX — Don't run it if you need DB data; use plain `docker compose down` to keep the volume.

## 15. `docker system df`
↓ PURPOSE — Show disk usage of images, containers, volumes, and build cache.
↓ WHAT IT DOES — Reports sizes and reclaimable space.
↓ EXPECTED OUTPUT — `Images space usage: ... 100MB ... Reclaimable`.
↓ COMMON ERROR — None.
↓ FIX — Use `docker system prune` if reclaimable space is large.

## 16. `docker system prune`
↓ PURPOSE — Remove unused images, containers, networks, and cache.
↓ WHAT IT DOES — Deletes everything not in use; `-a` also removes dangling images.
↓ EXPECTED OUTPUT — `Deleted Containers: ... Total reclaimed space: ...`.
↓ COMMON ERROR — Accidental deletion of needed data.
↓ FIX — Use `docker system prune -f` carefully; named volumes are kept unless you add `--volumes`.

## 17. `docker inspect app-node`
↓ PURPOSE — Inspect low-level details of a container.
↓ WHAT IT DOES — Prints JSON: state, health, mounts, network settings, env, image.
↓ EXPECTED OUTPUT — A long JSON document with `"State": {"Health": {"Status": "healthy"}}`.
↓ COMMON ERROR — `No such object: app-node`.
↓ FIX — Check `docker ps -a` for the correct name.

## 18. `docker rm app-test`
↓ PURPOSE — Remove a stopped container.
↓ WHAT IT DOES — Deletes the container (not the image); `-f` forces removal of a running one.
↓ EXPECTED OUTPUT — The container name echoed back.
↓ COMMON ERROR — `You cannot remove a running container`.
↓ FIX — Stop it first: `docker stop app-test`, or use `docker rm -f app-test`.

## 19. `docker rmi dockerized-app:latest`
↓ PURPOSE — Remove an image.
↓ WHAT IT DOES — Deletes the image locally, but fails if a container references it.
↓ EXPECTED OUTPUT — `Untagged: dockerized-app:latest`.
↓ COMMON ERROR — `image is being used by running container`.
↓ FIX — Remove the container first: `docker rm -f app-node` then retry.
