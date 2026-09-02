# Commands Cheat Sheet

Every command below follows the same format:

```
COMMAND
↓ PURPOSE
↓ WHAT IT DOES
↓ EXPECTED OUTPUT
↓ COMMON ERROR
↓ FIX
```

---

### 1. Java version (host, for reference only — Jenkins runs in a container)

```bash
java -version
```
↓ PURPOSE
Verify the local Java runtime (not required for this demo — Jenkins bundles its own JDK in the container).
↓ WHAT IT DOES
Prints the JVM version and vendor line.
↓ EXPECTED OUTPUT
`openjdk version "21.0.x"` (or similar).
↓ COMMON ERROR
`'java' is not recognized` — Java not installed on the host.
↓ FIX
Install Java or ignore it; the `jenkins/jenkins` image already includes a JDK.

---

### 2. Docker version

```bash
docker version
```
↓ PURPOSE
Confirm the Docker client and daemon are installed and compatible.
↓ WHAT IT DOES
Shows client + server versions and engine info.
↓ EXPECTED OUTPUT
A client section and a server section, both with a version number.
↓ COMMON ERROR
`Cannot connect to the Docker daemon`.
↓ FIX
Start Docker Desktop / the docker service, or check user permissions (add yourself to the `docker` group on Linux).

---

### 3. Start Jenkins with Docker Compose

```bash
docker compose -f jenkins/docker-compose.yml up -d --build
```
↓ PURPOSE
Build and start the Jenkins controller container.
↓ WHAT IT DOES
Builds `jenkins/Dockerfile`, creates the `jenkins_home` volume, mounts `docker.sock` + JCasC config, starts the container detached.
↓ EXPECTED OUTPUT
`Container jenkins Created` / `Started jenkins`.
↓ COMMON ERROR
Port 8080 already in use → `Bind for 0.0.0.0:8080 failed`.
↓ FIX
Stop the process on 8080 (`docker ps` / `netstat -ano | findstr 8080`) or change `JENKINS_HTTP_PORT` in `.env`.

---

### 4. Stop and remove Jenkins container

```bash
docker compose -f jenkins/docker-compose.yml down
```
↓ PURPOSE
Stop the Jenkins container (data persists in the volume unless you add `-v`).
↓ WHAT IT DOES
Stops and removes the container and network.
↓ EXPECTED OUTPUT
`Container jenkins Stopped / Removed`.
↓ COMMON ERROR
`no such service` — running from the wrong directory or wrong file path.
↓ FIX
Run from the project root and pass `-f jenkins/docker-compose.yml`.

---

### 5. Shell into the Jenkins container

```bash
docker exec -it jenkins bash
```
↓ PURPOSE
Open an interactive shell inside the Jenkins container for debugging.
↓ WHAT IT DOES
Runs `bash` inside the running `jenkins` container.
↓ EXPECTED OUTPUT
A root prompt (`root@<container-id>:/#`).
↓ COMMON ERROR
`cannot exec in a stopped state`.
↓ FIX
Start the container first: `docker start jenkins`.

---

### 6. Get the initial admin password

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```
↓ PURPOSE
Retrieve the one-time unlock password on first Jenkins boot.
↓ WHAT IT DOES
Reads the initial admin password file from the Jenkins home volume.
↓ EXPECTED OUTPUT
A 32-char hex string.
↓ COMMON ERROR
`No such file or directory` — Jenkins already unlocked, or JCasC bootstrapped users.
↓ FIX
Log in with the JCasC admin user from `jenkins/config-as-code/jenkins.yaml`, or view `/var/jenkins_home/users` to recover.

---

### 7. Query the Jenkins REST API (JSON)

```bash
curl -u admin:TOKEN "http://localhost:8080/api/json?tree=jobs[name,url]"
```
↓ PURPOSE
List Jenkins jobs via the REST API.
↓ WHAT IT DOES
Authenticates with an API token and returns job metadata as JSON.
↓ EXPECTED OUTPUT
`{"_class":"hudson.model.Hudson","jobs":[{"name":"hello-app-pipeline","url":...}]}`.
↓ COMMON ERROR
`403 Forbidden` / `401 Unauthorized` — wrong credentials, or CSRF crumb required.
↓ FIX
Use a real API token (Profile → Configure → API Token) and, for `POST` calls, send the `Jenkins-Crumb` header (see #10).

---

### 8. Jenkins CLI

```bash
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:TOKEN list-jobs
```
↓ PURPOSE
Drive Jenkins from the command line (build, list, version…).
↓ WHAT IT DOES
Downloads/uses the `jenkins-cli.jar` client to call Jenkins over HTTP.
↓ EXPECTED OUTPUT
A list of job names, e.g. `hello-app-pipeline`.
↓ COMMON ERROR
`java.lang.IllegalStateException: ... -ssh` → SSH transport requires extra args; or wrong JAR version.
↓ FIX
Use `-s http://localhost:8080/ -auth user:token`, and download the JAR from `http://localhost:8080/jnlpJars/jenkins-cli.jar`.

---

### 9. Trigger a build over REST (POST)

```bash
curl -u admin:TOKEN -X POST "http://localhost:8080/job/hello-app-pipeline/build"
```
↓ PURPOSE
Kick off a pipeline build from the command line.
↓ WHAT IT DOES
POSTs a build request to the job.
↓ EXPECTED OUTPUT
`HTTP/1.1 201 Created` (no body).
↓ COMMON ERROR
`403 No valid crumb was included in the request`.
↓ FIX
Fetch a crumb first and send it:
```bash
CRUMB=$(curl -s -u admin:TOKEN "http://localhost:8080/crumbIssuer/api/json" | tr -d '{}' | sed 's/.*crumb":"\([^"]*\)".*/\1/')
curl -u admin:TOKEN -H "Jenkins-Crumb: $CRUMB" -X POST "http://localhost:8080/job/hello-app-pipeline/build"
```

---

### 10. Check build status

```bash
curl -s -u admin:TOKEN "http://localhost:8080/job/hello-app-pipeline/lastBuild/api/json" | jq .result
```
↓ PURPOSE
Get the result of the last build (`SUCCESS` / `FAILURE`).
↓ WHAT IT DOES
Reads build metadata from the API.
↓ EXPECTED OUTPUT
`"SUCCESS"`.
↓ COMMON ERROR
`jq: command not found`.
↓ FIX
Install jq, or read `.../lastBuild/api/json` without `| jq .result`.

---

### 11. Git — clone the repo

```bash
git clone https://github.com/<USER>/<REPO>.git
```
↓ PURPOSE
Download the repository locally.
↓ WHAT IT DOES
Copies all branches/history into a working directory.
↓ EXPECTED OUTPUT
`Cloning into '<REPO>'... done.`
↓ COMMON ERROR
`fatal: could not read Username for 'https://github.com'`.
↓ FIX
Use a PAT as the password, or clone via SSH (`git@github.com:<USER>/<REPO>.git`) with your SSH key loaded.

---

### 12. Git — stage and commit

```bash
git add . && git commit -m "message"
```
↓ PURPOSE
Record local changes with a message.
↓ WHAT IT DOES
Stages all changes and creates a commit.
↓ EXPECTED OUTPUT
`[main abc1234] message` with the changed file list.
↓ COMMON ERROR
`nothing to commit, working tree clean`.
↓ FIX
Actually change a file first, or use `git add -A`.

---

### 13. Git — push to remote

```bash
git push origin main
```
↓ PURPOSE
Upload local commits to GitHub (triggers the webhook).
↓ WHAT IT DOES
Pushes the `main` branch to `origin`.
↓ EXPECTED OUTPUT
`To https://github.com/...` and branch summary lines.
↓ COMMON ERROR
`! [rejected] ... fetch first` — remote has newer commits.
↓ FIX
`git pull --rebase origin main` then push again.

---

### 14. Git — revert the last commit (rollback)

```bash
git revert HEAD && git push origin main
```
↓ PURPOSE
Roll back the last change and redeploy through the pipeline.
↓ WHAT IT DOES
Creates a new commit that undoes `HEAD`, then pushes it; Jenkins rebuilds the previous good code.
↓ EXPECTED OUTPUT
`Revert "previous message"` commit pushed.
↓ COMMON ERROR
`error: your local changes would be overwritten`.
↓ FIX
Commit or stash your local changes first (`git stash`).

---

### 15. Build the app image

```bash
docker build -t hello-app:1 ./app
```
↓ PURPOSE
Build the Docker image for the app.
↓ WHAT IT DOES
Runs `app/Dockerfile` inside the `./app` build context.
↓ EXPECTED OUTPUT
`Successfully tagged hello-app:1`.
↓ COMMON ERROR
`failed to solve: ... node:24-alpine: failed to resolve`.
↓ FIX
Pull the base image explicitly: `docker pull node:24-alpine`, then retry (or fix network/proxy).

---

### 16. Run the app container

```bash
docker run -d --name hello-app-1 -p 8091:3000 hello-app:1
```
↓ PURPOSE
Start the app container detached.
↓ WHAT IT DOES
Maps host port 8091 → container port 3000 and names the container.
↓ EXPECTED OUTPUT
A container ID (hex string).
↓ COMMON ERROR
`port is already allocated` or `Conflict. The container name ... is already in use`.
↓ FIX
`docker rm -f hello-app-1` or change the host port; ensure no other container uses 8091.

---

### 17. List running containers

```bash
docker ps
```
↓ PURPOSE
Show running containers and their port mappings.
↓ WHAT IT DOES
Lists container ID, image, name, ports, status.
↓ EXPECTED OUTPUT
`CONTAINER ID  IMAGE  ...  hello-app-1  0.0.0.0:8091->3000/tcp  Up 2 minutes`.
↓ COMMON ERROR
Nothing listed even though you started a container.
↓ FIX
Check `docker ps -a` (includes stopped containers); the container may have exited — read `docker logs`.

---

### 18. View container logs

```bash
docker logs hello-app-1
```
↓ PURPOSE
Read application output from a container.
↓ WHAT IT DOES
Prints stdout/stderr from the container process.
↓ EXPECTED OUTPUT
`hello-app listening on http://localhost:3000`.
↓ COMMON ERROR
`Error response from daemon: No such container: ...`.
↓ FIX
`docker ps -a` to find the exact name/ID.

---

### 19. Test the app locally (host Node)

```bash
node --test
```
↓ PURPOSE
Run the test suite with the built-in Node test runner.
↓ WHAT IT DOES
Auto-discovers every test file under `test/` and runs them via `node:test`.
↓ EXPECTED OUTPUT
`# pass 5 / # fail 0` and `tests 5` summary.
↓ COMMON ERROR
`No test files found` or `SyntaxError` in a test file.
↓ FIX
Run from the `app/` directory: `cd app && node --test`; or fix the syntax error.

---

### 20. Syntax-check the server (no deps)

```bash
node --check server.js
```
↓ PURPOSE
Validate the app file's syntax without executing it.
↓ WHAT IT DOES
Parses `server.js` and prints nothing on success (exit 0).
↓ EXPECTED OUTPUT
(empty output, exit code 0)
↓ COMMON ERROR
A `SyntaxError: Unexpected token` printed with a file/line.
↓ FIX
Fix the reported line and re-run.

---

### 21. Trivy scan (via Docker)

```bash
docker run --rm aquasec/trivy:latest image --exit-code 0 --severity HIGH hello-app:1
```
↓ PURPOSE
Scan the built image for known vulnerabilities.
↓ WHAT IT DOES
Pulls the Trivy image, scans `hello-app:1`, prints a CVE table.
↓ EXPECTED OUTPUT
A vulnerability table + `Total: 0 (UNKNOWN: 0, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)`.
↓ COMMON ERROR
`No such image: hello-app:1` (image not built) or network issues pulling Trivy.
↓ FIX
Run `docker build -t hello-app:1 ./app` first; retry with `--no-progress`.

---

### 22. Docker Compose validate the Jenkins stack

```bash
docker compose -f jenkins/docker-compose.yml config
```
↓ PURPOSE
Validate and render the compose file without starting anything.
↓ WHAT IT DOES
Parses YAML, interpolates env vars, prints the resolved service definition.
↓ EXPECTED OUTPUT
The resolved `services:` YAML with all ports/volumes.
↓ COMMON ERROR
`expected a single document` / YAML indentation errors.
↓ FIX
Fix indentation (2 spaces) in the compose file, then re-run.

---

### 23. Jenkins log tail (monitoring)

```bash
docker logs --tail 100 jenkins
```
↓ PURPOSE
Inspect the Jenkins controller's log for startup errors or crashes.
↓ WHAT IT DOES
Prints the last 100 lines of the Jenkins container's stdout.
↓ EXPECTED OUTPUT
Jenkins startup lines, finally `Jenkins is fully up and running`.
↓ COMMON ERROR
Repeated OOM stack traces (`java.lang.OutOfMemoryError: Java heap space`).
↓ FIX
Raise `-Xmx` in `JAVA_OPTS` in the compose file, or increase Docker memory.
