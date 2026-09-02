# Interview Questions & Answers

Twelve questions covering the concepts in this project, with concise, accurate answers you can say out loud in an interview.

---

## Q1. What is Continuous Integration (CI)? What is Continuous Delivery (CD)? What is the difference?

- **CI** is the practice of automatically integrating code changes into a shared repo **many times a day** and verifying each change with an automated build + test (e.g. our Jenkins pipeline running `node --check` and `node --test` on every push). It catches integration problems early.
- **CD (Continuous Delivery)** extends CI: after a green build, the artifact is automatically prepared and ready to deploy to any environment (here, a Docker image + health check). **Continuous Deployment** goes further and deploys to production automatically.
- **Difference:** CI answers "does the change integrate and pass tests?"; CD answers "is it shippable and actually deployed?". CI ends at verified artifacts; CD takes them into environments.

## Q2. Why Jenkins? Couldn't you just script it?

- Jenkins adds **triggering, scheduling, orchestration, visibility, and persistence** on top of raw scripts:
  - It knows *when* to run (webhook, cron/polling) and runs stages **in order** with per-stage pass/fail.
  - Every run gets a **number, console log, and status**; failures are attributable to a commit.
  - 1000+ **plugins** (git, docker-workflow, Blue Ocean, JCasC, credentials) are maintained and battle-tested.
  - A raw script has no UI, no history, no credential store, no retry/notification story.
- Trade-off: Jenkins itself must be operated (here, as a Docker container).

## Q3. Jenkinsfile (declarative pipeline) vs a freestyle job?

- A **freestyle job** configures build steps through UI checkboxes/forms; the configuration lives in Jenkins and is easy to click but hard to review, version, or reproduce.
- A **Jenkinsfile** is the build definition **as code**, committed next to the app. It's version-controlled, reviewable in pull requests, portable across controllers, and rebuildable from history. Declarative gives a readable `stages/options/post` skeleton; scripted gives raw Groovy flexibility.
- Rule of thumb: always prefer Pipeline as Code.

## Q4. What happens when a build fails in your pipeline?

- The failing **stage** goes red; Jenkins stops executing subsequent stages (declarative aborts on failure unless `unstable`/`continueOnError` is used).
- The `post { failure { ... } }` block runs (we print guidance + ensure cleanup). `post { always { ... } }` guarantees the container is removed even on failure.
- The console log + Blue Ocean view show exactly which stage and assertion broke; the result (`FAILURE`) and the culprit commit are linked.

## Q5. How do you make a stage optional?

- Wrap it in `script { }` with a condition: `when { expression { return fileExists('trivy') || <condition> } }` skips the whole stage, or inside steps do `script { if (condition) { ... } else { echo 'skipping' } }`.
- Our Trivy stage does exactly this: it checks whether the binary/Docker image exists and **skips gracefully** (prints a notice) when unavailable, instead of failing the build.

## Q6. What is a webhook, and how does Jenkins know a new commit exists?

- A **webhook** is an HTTP POST that GitHub sends to a URL when an event happens (here: a push).
- In this project: push → GitHub sends `POST http://<host>:8080/github-webhook/` → Jenkins matches it to the job via the GitHub plugin and triggers a build.
- Without webhooks, Jenkins **polls** the repo on a schedule (`H/5 * * * *`) — wasteful but works behind firewalls. Jenkins also stores the last built commit per branch, so it knows exactly which commit to check out and builds each once.

## Q7. What are Jenkins Shared Libraries?

- A way to package **reusable pipeline steps/functions** (e.g. `buildDockerImage()`, `notifySlack()`) in a separate git repo, and `@Library('my-lib') _` loads them into the Jenkinsfile.
- Benefit: common logic lives in one versioned place instead of being copy-pasted into every pipeline; DRY + testable. Overkill for this single-app demo, essential for many teams/apps.

## Q8. What does mounting `/var/run/docker.sock` into Jenkins do, and what's the risk?

- It lets Jenkins run the **Docker CLI** and control the host's Docker daemon directly (Docker-outside-of-Docker), so the pipeline can `docker build` / `docker run` without a nested daemon.
- **Risk:** the Docker socket is effectively **root on the host** — any process in the Jenkins container (a malicious pipeline or compromised plugin) can mount the host filesystem into a container and take over the machine. That's why this pattern is demo-only; production uses DinD on a sandboxed VM or ephemeral build agents.

## Q9. How do you secure Jenkins?

- **Credentials:** store secrets in the encrypted Credentials store (never in the Jenkinsfile), use PATs with minimal scopes, bind with `credentials('id')`.
- **Access control:** RBAC via a security realm + authorization strategy (`loggedInUsersCanDoAnything`, Matrix/role-based auth for teams), disable signup, disallow anonymous.
- **Controller:** change default admin password, keep CSRF enabled, use API tokens, sandbox the socket mount (or remove it), and keep `jenkins_home` backed up.
- **Supply chain:** pin/update plugins, watch Jenkins security advisories, run Trivy/Dependabot, enforce `--exit-code 1` on critical findings in prod.

## Q10. How would you move this pipeline to GitHub Actions?

- Add `.github/workflows/ci.yml`; `on: push` + `pull_request` replaces the webhook. Steps: `actions/checkout@v4`, then `setup-node`, `npm test` (or `node --test`), and `docker build` using `docker/build-push-action@v6` with the built-in `GITHUB_TOKEN` for auth.
- Equivalent of `buildDiscarder` = retention settings; secrets via repo **Actions secrets** (`${{ secrets.GITHUB_TOKEN }}`); the `docker.sock` risk disappears because each job already runs on a fresh runner.

## Q11. What is Blue Ocean?

- A modern Jenkins UI/plugin (and the `blueocean` plugin in `plugins.txt`) that renders each pipeline run as **colorful stage cards** — green stages = pass, red = fail — plus live logs and a friendlier editor. It doesn't change pipeline behavior; it's a visualization layer that makes CI results legible for non-experts.

## Q12. How do you parametrize a pipeline?

- Use `parameters { string(name: 'ENV', defaultValue: 'dev', ...); choice(name: 'APP_VERSION', choices: ['1.0.0','1.1.0']) }` in the Jenkinsfile; values appear in the "Build with Parameters" dialog and are read as `params.ENV` / `params.APP_VERSION`.
- Trigger with values over the API: `curl -X POST .../buildWithParameters?ENV=staging`. Credentials and images can also be selected via parameters — keep defaults safe and validate inputs (Job DSL/Groovy sanitization).
