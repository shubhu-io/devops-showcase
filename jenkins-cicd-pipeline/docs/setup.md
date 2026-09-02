# Setup

Step-by-step guide to run the whole demo on a local machine.

## Prerequisites

- **Docker Desktop (or Docker Engine) with Docker Compose v2** — required.
- **Git** — required.
- **Java is NOT needed.** Jenkins runs inside a container; the `jenkins/jenkins` image bundles its own JDK. This is one of the benefits of running Jenkins in Docker.
- **Node.js** — only needed if you want to run the tests/build directly on your host (`node --check`, `node --test`). The Jenkins controller image also ships Node, so host Node is optional.
- ~2–4 GB free RAM for the Jenkins container + the app container.

## 1. Clone the repo

```bash
git clone https://github.com/<YOUR_USERNAME>/<YOUR_REPO>.git
cd <YOUR_REPO>/jenkins-cicd-pipeline
```

## 2. Start Jenkins with Docker Compose

```bash
docker compose -f jenkins/docker-compose.yml up -d --build
```

This builds the controller image (Jenkins LTS + Docker CLI + Node.js), creates the `jenkins_home` volume, mounts `/var/run/docker.sock` and the JCasC config, and exposes ports 8080/50000.

## 3. Unlock Jenkins (first boot)

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Open http://localhost:8080 and paste the password.

> Because JCasC is mounted, Jenkins may be configured on boot already — in that case log in with the admin user from `jenkins/config-as-code/jenkins.yaml` (default `admin` / `change-me-admin-password` — **change it**).

## 4. Install suggested plugins

On the *Customize Jenkins* screen choose **Install suggested plugins** (or let the JCasC plugin list preload — `jenkins/plugins.txt`). The essential ones for this project are already in `plugins.txt`:

- `workflow-aggregator` (pipeline), `git`, `docker-workflow`, `pipeline-utility-steps`, `blueocean`, `credentials-binding`, `ws-cleanup`, `htmlpublisher`, `configuration-as-code`, `timestamper`.

## 5. Create the pipeline job

Two options:

**Option A — Pipeline job (simplest):**
1. New Item → name `hello-app-pipeline` → **Pipeline**.
2. Under **Pipeline**, select *Pipeline script from SCM*.
3. SCM: **Git**, Repo URL: `https://github.com/<YOUR_USERNAME>/<YOUR_REPO>.git`.
4. If the repo is private, add a credential (step 6) and select it.
5. Script Path: `Jenkinsfile` (it lives at the repo root).
6. Save.

**Option B — Multibranch Pipeline (branch/PR awareness):**
1. New Item → **Multibranch Pipeline** → add a Git branch source pointing at the repo.
2. Jenkins auto-discovers branches containing a `Jenkinsfile` and builds them.
3. Add a webhook so each push builds automatically (see step 7).

## 6. Define credentials

- **GitHub (private repos / API):** Manage Jenkins → Credentials → Global → **Add Credentials** → kind *Username with password*. Username = your GitHub username; Password = a **Personal Access Token** (GitHub → Settings → Developer settings → PAT, scope `repo`). Set ID to `github-creds` (matches the placeholder ID referenced in the Jenkinsfile).
- **Docker Hub (for registry push):** same place, ID `docker-registry-creds`.

> Credentials are stored (encrypted) in the Jenkins Credentials store — never in the Jenkinsfile. See [security.md](security.md).

## 7. (Optional but recommended) Webhook trigger

1. GitHub repo → Settings → Webhooks → Add webhook.
2. Payload URL: `http://<YOUR_HOST_IP>:8080/github-webhook/` (use the machine's LAN IP, not `localhost`, if Jenkins is elsewhere).
3. Content type: `application/json`. Select **Just the push event** → Add webhook.

If a webhook isn't possible, set the job to **Poll SCM** (e.g. `H/5 * * * *`).

## 8. Run the build

```bash
# from the Jenkins UI
# Job page -> Build Now, or:
curl -u admin:TOKEN -X POST "http://localhost:8080/job/hello-app-pipeline/build"
```

Watch it in **Blue Ocean** (click *Open Blue Ocean* on the job page). All 8 stages should go green.

## 9. Verify the app

```bash
# Host port for build #1 is 8091 (8090 + build_number % 10)
curl http://localhost:8091/health     # {"status":"ok"}
curl http://localhost:8091/           # HTML page
curl http://localhost:8091/api/message
```

## 10. Demonstrate a failing build (optional)

In `app/test/example-failing.js` change `EXPECTED` to `"fail"`, commit, push, rebuild — the **Test** stage goes red. Change it back to `"pass"` and rebuild to restore green. See [docs/troubleshooting.md](troubleshooting.md) for failure fixes.
