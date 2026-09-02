# Troubleshooting

Every entry: **Problem / Cause / How to diagnose / Solution / Prevention**.

---

## 1. Jenkins build fails (generic)

- **Problem:** A build goes red; you're not sure why.
- **Cause:** Could be any stage — checkout, syntax, test, docker, health.
- **How to diagnose:** Open the build → **Console Output** (or Blue Ocean) and read the first `ERROR`/`FAILURE` line; find which **stage** is red.
- **Solution:** Fix per the specific entries below; `post.failure` also prints a hint pointing to `docs/troubleshooting.md`.
- **Prevention:** Keep stages small and named; add `echo` markers; fix the failing test before changing code.

---

## 2. Git authentication failure (`Host key verification failed` / `cannot open .git/FETCH_HEAD`)

- **Problem:** Checkout stage fails with `Host key verification failed` or `error: cannot open .git/FETCH_HEAD: Permission denied`.
- **Cause:** SSH host key of GitHub not in `known_hosts` (agent workspace), or the git user inside the container can't write `.git` (permission/ownership), or wrong credentials.
- **How to diagnose:** `git ls-remote git@github.com:user/repo.git` on the agent; inspect `.git/FETCH_HEAD` ownership: `ls -la .git/`.
- **Solution:** Pre-seed `known_hosts` (e.g. `ssh-keyscan github.com >> known_hosts`) in the image; `chown -R jenkins .git`; for HTTPS use a credential with a PAT.
- **Prevention:** Use HTTPS + `credentialsId`, or build `known_hosts` into the Jenkins image.

---

## 3. Docker daemon unavailable inside Jenkins (`cannot connect to the docker daemon` / permission denied on `/var/run/docker.sock`)

- **Problem:** `docker build`/`docker run` stages fail with `Cannot connect to the Docker daemon` or `Got permission denied while trying to connect to the Docker Unix socket`.
- **Cause:** The socket isn't mounted, or the `jenkins` user isn't in the host `docker` group whose GID the socket uses.
- **How to diagnose:** `docker exec jenkins docker version`; `docker exec jenkins ls -la /var/run/docker.sock`; on the host `ls -n /var/run/docker.sock` to see the group GID.
- **Solution:** Ensure the compose file mounts `/var/run/docker.sock:/var/run/docker.sock`; the Dockerfile adds the `docker` group with GID 999 and adds `jenkins` to it. If the host group has a different GID, change `--gid 999` to match.
- **Prevention:** Keep the DooD mount + group in sync with the host (see `docs/security.md` for risks).

---

## 4. Port already in use — 8080

- **Problem:** `docker compose up` fails: `Bind for 0.0.0.0:8080 failed: port is already allocated`.
- **Cause:** Another process/container already listens on host port 8080.
- **How to diagnose:** `docker ps` (other containers) or `netstat -ano | findstr 8080` / `lsof -i :8080`.
- **Solution:** Stop the other process, or change `JENKINS_HTTP_PORT` in `.env` to e.g. `18080` and reuse (UI at `http://localhost:18080`).
- **Prevention:** Choose a less contested port up front; document it in `.env`.

---

## 5. Jenkins stuck / out of memory

- **Problem:** Jenkins UI unresponsive, builds hang, or container restarts.
- **Cause:** Heap exhaustion (plugins + big builds) or the container hitting Docker's memory limit.
- **How to diagnose:** `docker logs --tail 100 jenkins` for `java.lang.OutOfMemoryError`; `docker stats jenkins`.
- **Solution:** Raise `-Xmx` in `JAVA_OPTS` (currently `2048m`) in the compose file; increase Docker Desktop's memory; restart the container (`docker compose -f jenkins/docker-compose.yml restart`).
- **Prevention:** `disableConcurrentBuilds()` in the Jenkinsfile; trim plugins; monitor `docker stats`.

---

## 6. Pipeline not found / no Jenkinsfile

- **Problem:** Build says `Notifying ... as expected` then `Stage "..." skipped` or "No such DSL method", or a Multibranch repo shows no branches.
- **Cause:** Job's script path doesn't match where the `Jenkinsfile` actually is (repo root here), or the branch source filter excludes `main`.
- **How to diagnose:** Look at job config → Pipeline → Script Path; check the repo root for `Jenkinsfile`.
- **Solution:** Set Script Path to `Jenkinsfile`; for Multibranch enable "Discover branches" with `*/main` and make sure the file is committed.
- **Prevention:** Keep `Jenkinsfile` at repo root; commit it (it is version-controlled as code).

---

## 7. `NoSuchMethodError` for steps

- **Problem:** A `sh`, `docker`, `curl`, or `fileExists` step throws `NoSuchMethodError`.
- **Cause:** A required plugin is missing (e.g. `workflow-aggregator` for `sh` in declarative, `docker-workflow` for `docker` steps) or the controller's plugin set is stale.
- **How to diagnose:** Console log shows `java.lang.NoSuchMethodError: No such DSL method 'sh'` (usually "steps" module missing) — check **Manage Jenkins → Plugins → Installed**.
- **Solution:** Install the plugin from `jenkins/plugins.txt` (workflow-aggregator, docker-workflow, pipeline-utility-steps) and restart.
- **Prevention:** Keep `plugins.txt` in sync and restart after plugin changes.

---

## 8. Trivy not found

- **Problem:** Security stage shows `trivy: command not found` — or, with this Jenkinsfile, it logs **"SKIPPING security scan"**.
- **Cause:** Trivy is not installed on the agent and the Trivy Docker image isn't available.
- **How to diagnose:** `which trivy`; `docker images | grep trivy`.
- **Solution:** The pipeline already degrades gracefully (it prints a SKIP note). To enable the scan, either install the Trivy binary on the agent or let it use `docker run aquasec/trivy` (needs internet).
- **Prevention:** Pre-pull the Trivy image (`docker pull aquasec/trivy`) during setup.

---

## 9. Container health check failing

- **Problem:** Health Check stage fails with `UNHEALTHY` or curl exits non-zero.
- **Cause:** App crashed on boot, wrong port mapping, or the wait loop was too short.
- **How to diagnose:** `docker ps -a` (did the container exit?), `docker logs hello-app-N`, and `curl -v http://localhost:809N/health` on the host.
- **Solution:** Fix the port mapping (`-p 809N:3000` where 3000 = `APP_PORT`), fix the app, or extend the wait loop (15 × 1s in the Jenkinsfile).
- **Prevention:** The Dockerfile `HEALTHCHECK` and the pipeline wait loop catch this earlier; test locally with `scripts/healthcheck.sh`.

---

## 10. Build fails at the Test stage

- **Problem:** Test stage red; console shows an assertion failure.
- **Cause:** `app/test/example-failing.js` was toggled (its `EXPECTED` constant set to `fail`), or `server.js` broke an endpoint.
- **How to diagnose:** Read the failing test name in the console output; run `node --test` locally in `app/`.
- **Solution:** Set `EXPECTED` back to `pass` in `test/example-failing.js`, or fix the app, commit, rebuild.
- **Prevention:** Keep the demo test green by default; fix app code before pushing.

---

## 11. Jenkins cannot pull an image (registry auth)

- **Problem:** `docker pull` or `docker build` fails with `denied: requested access to the resource is denied` / `unauthorized`.
- **Cause:** Pulling a private image or hitting Docker Hub rate limits without login.
- **How to diagnose:** `docker pull <image>` manually on the agent; check `docker login`.
- **Solution:** `echo "$DOCKERHUB_TOKEN" | docker login -u "$USER" --password-stdin` (or use the `docker-registry-creds` credential via `withCredentials`), then retry.
- **Prevention:** Store registry creds in the Credentials store; log in in the pipeline when pushing/pulling private images.

---

## 12. Blue Ocean not loading

- **Problem:** Clicking "Open Blue Ocean" shows a blank page or an error.
- **Cause:** `blueocean` plugin missing, browser cache, or the controller is on an old plugin set.
- **How to diagnose:** Check plugins (`blueocean` installed?); hard-refresh the page; check the browser console for 500s.
- **Solution:** Install/update `blueocean`, restart Jenkins, hard-refresh (Ctrl+F5), or use classic UI + `pipeline-stage-view` (installed too).
- **Prevention:** Keep Blue Ocean updated in `plugins.txt`.

---

## 13. Disk full on jenkins_home

- **Problem:** Builds fail with `No space left on device`; Jenkins UI slow.
- **Cause:** The `jenkins_home` Docker volume grows: workspaces, build logs, plugin updates.
- **How to diagnose:** `docker system df`; `docker exec jenkins du -sh /var/jenkins_home/*`; `df -h` on the volume mount.
- **Solution:** `docker rm -f jenkins && docker volume rm jenkins_home` (only if no important state — back up first), or prune inside: delete old workspaces via `ws-cleanup` and `buildDiscarder` retention.
- **Prevention:** The Jenkinsfile keeps 10 builds with `buildDiscarder`; run `ws-cleanup` at the end; periodically `docker system prune`.
