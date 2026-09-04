# Interview Questions

1. **What is the difference between a Docker image and a Docker container?**
   An image is an immutable, layered template (source code + runtime + config) built from a Dockerfile and stored on disk/registry. A container is a running instance of an image — an isolated process with its own filesystem, network, and PID namespace. One image can produce many containers (`docker run` per instance); containers share the host kernel.

2. **What is the difference between a Dockerfile and Docker Compose?**
   A Dockerfile defines how to build a single image (base, commands, env, entrypoint). Docker Compose is a YAML orchestrator that defines the multi-container app topology — services, networks, volumes, port mappings, healthchecks, dependency order — and turns it into `docker compose up` / `down`. Dockerfile = how one image is built; Compose = how the whole system is run.

3. **Why use a multi-stage build?**
   To separate build-time tooling from the runtime image. The `builder` stage compiles/bundles and installs dev dependencies; the `runtime` stage copies only the artifacts and runs as a minimal, non-root image. Result: smaller images, fewer attack-surface components, faster pulls, and no compilers/packagers shipped to production.

4. **How do containers on the same Docker network communicate?**
   They share a virtual bridge network (default `bridge`). Docker runs an embedded DNS server that resolves container names to their IPs on that network, so services can talk to each other by service/container name (e.g., `app` reaching `db:5432`). External traffic reaches them only through published ports on the host.

5. **Why do we need health checks?**
   Containers are ready at different speeds (e.g., Postgres takes seconds to accept connections). Health checks make readiness observable: Docker marks a container `healthy`/`unhealthy`, compose `depends_on` conditions gate startup order, and orchestrators use them for auto-restart and traffic draining. Without them, nginx would proxy to a still-booting app and return 502s.

6. **What is the difference between a container and a VM?**
   Both isolate workloads, but a VM virtualizes hardware and runs a full guest OS (heavy: GBs, slow start, hypervisor overhead). A container shares the host kernel and packages only the app + its dependencies (MBs, sub-second start). Containers trade isolation strength (shared kernel) for efficiency; VMs give stronger isolation at higher cost.

7. **How do you persist database data when the DB runs in a container?**
   Mount a named volume (`pgdata:/var/lib/postgresql/data`). Volumes live on the host (managed by Docker) and survive container restarts and `compose down` (without `-v`). Only `docker compose down -v` deletes them, which is why that flag is flagged as destructive.

8. **How does Docker cache layers?**
   Each Dockerfile instruction becomes a layer. When rebuilding, Docker reuses any layer whose instruction and inputs (base image, copied files, build args) are unchanged, skipping execution. Copying smaller files first and stable instruction order maximize cache hits. Any change invalidates that layer and everything after it; `--no-cache` bypasses the cache.

9. **Why is `docker compose down -v` dangerous?**
   `-v` removes named volumes, so it permanently deletes the database contents in `pgdata`. Recovery requires a backup. Use plain `docker compose down` to stop the stack while keeping data, and back up the volume before any `-v` cleanup.

10. **How do you debug a failing container?**
    1) `docker compose logs <service>` — app output. 2) `docker ps -a` — see crash loop status. 3) `docker inspect <name>` — exit code, health history, mounts, env. 4) `docker exec -it <name> sh` — interactive shell inside a running container to test commands. 5) Read the Dockerfile/compose config for the app's actual port/paths.

11. **How does Docker image layering work?**
     A Dockerfile instruction (FROM, COPY, RUN, ENV, etc.) creates an immutable layer stacked on the previous one; the runtime merges them into one filesystem view (copy-on-write). Layers are content-addressed and shared between images, so a base like `node:22-alpine` is downloaded once and reused — this is why layer caching and small layers speed up builds and saves disk.

12. **What is the difference between the `bridge` and `host` Docker networks?**
     `bridge` (default) puts containers on an isolated NAT'd virtual network with their own IPs; published ports map to the host, and the container DNS resolves names. `host` removes network isolation: the container shares the host's network stack directly (no port mapping; the app binds the host interface). Bridge is safer and the compose default; host is used when low latency or many ports matter and isolation is acceptable.
