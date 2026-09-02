# Troubleshooting Guide

Each entry follows: **Problem / Cause / How to diagnose / Solution / Prevention**.

---

## 1. SSH: `Permission denied (publickey)` to EC2

- **Problem:** `ssh -i devops-key.pem ubuntu@IP` fails with `Permission denied (publickey)`.
- **Cause:** wrong key pair, key perms too open, wrong user, or public key not on
  the instance.
- **Diagnose:**
  ```bash
  ssh -vvv -i ~/.ssh/devops-key.pem ubuntu@IP   # verbose: which key is tried, server messages
  ls -l ~/.ssh/devops-key.pem                    # must be -r-------- (400)
  ```
- **Solution:** `chmod 400 ~/.ssh/devops-key.pem`; confirm you launched the instance
  with the SAME key name; use `ubuntu@` (or the AMI's default user).
- **Prevention:** name keys explicitly (`devops-key`), keep a single copy in
  `~/.ssh/`, document the user in the README.

---

## 2. SSH/HTTP: Timeout while connecting to EC2

- **Problem:** `ssh` or `curl http://IP` hangs then times out.
- **Cause:** security group rule missing (22 or 80), wrong source IP, instance
  stopped, or a misconfigured VPC/route table.
- **Diagnose:**
  ```bash
  aws ec2 describe-instances --instance-ids <id>  # State must be "running"
  aws ec2 describe-security-groups --group-ids <sg>  # verify inbound rules
  ping -n 4 <IP>                                   # basic reachability (may still block ICMP)
  ```
- **Solution:** add `22 from YOUR_IP/32` and `80 from 0.0.0.0/0` to the SG; start the
  instance; verify the IP didn't change after a stop/start.
- **Prevention:** use an **Elastic IP** if the address must stay stable; document SG
  rules in [setup.md](setup.md).

---

## 3. Jenkins cannot SSH: host key verification / no such identity file

- **Problem:** Jenkins pipeline fails at Transfer/Deploy stage with
  `Host key verification failed` or `Could not open a required tty / No such identity file`.
- **Cause:** agent has no host key for the EC2 host (first connect), or the
  `ec2-key` credential doesn't contain the private key.
- **Diagnose:** look at the console log stage; run `ssh -o StrictHostKeyChecking=accept-new ubuntu@IP` once from the Jenkins host.
- **Solution:** the Jenkinsfile already uses `StrictHostKeyChecking=accept-new`
  on first connect. Verify Credentials → `ec2-key` → "SSH Username with private key"
  has the FULL `.pem` contents (including `-----BEGIN/END-----` lines) and the
  ID matches `sshagent(['ec2-key'])`.
- **Prevention:** never rely on manual first-connect; keep `accept-new` in pipeline
  SSH commands; test the credential with a manual Build Now.

---

## 4. Docker daemon not running on EC2

- **Problem:** deploy stage reports `Cannot connect to the Docker daemon` /
  `Is the docker daemon running?`.
- **Cause:** Docker never installed (bootstrap failed) or the daemon stopped.
- **Diagnose:**
  ```bash
  ssh ubuntu@IP 'systemctl status docker; ls /opt/devops/bootstrap-done'
  ssh ubuntu@IP 'cat /var/log/cloud-init-output.log | tail -50'   # bootstrap errors
  ```
- **Solution:** `sudo systemctl enable --now docker`; re-run
  `bash scripts/ec2-bootstrap.sh`; fix the failing apt/docker repo line from the
  cloud-init log.
- **Prevention:** user-data is idempotent-ish — add `set -euo pipefail` (already in
  the script) and check the `bootstrap-done` marker before deploying.

---

## 5. Port 80 already in use on EC2

- **Problem:** `docker run -p 80:3000` fails with `port is already allocated` /
  `Bind for 0.0.0.0:80 failed`.
- **Cause:** another process (e.g. Apache/`systemd`-installed nginx) or a stale
  container already owns port 80.
- **Diagnose:**
  ```bash
  ssh ubuntu@IP 'sudo lsof -i :80; docker ps -a | grep node-app; sudo ss -ltnp | grep :80'
  ```
- **Solution:** stop the conflicting service or remove the stale container
  (`docker rm -f node-app`); or use the documented layout — container on
  `127.0.0.1:3000`, Nginx owns 80.
- **Prevention:** standardize on one layout (this project: Nginx on 80, container
  on 3000) and make `deploy.sh` stop the old container before starting the new one.

---

## 6. Container exits immediately

- **Problem:** `docker ps` shows no `node-app`; `docker ps -a` shows `Exited (1)`.
- **Cause:** app crash (bad code, missing env), or port bind conflict at startup.
- **Diagnose:**
  ```bash
  ssh ubuntu@IP 'docker logs --tail 100 node-app'
  ssh ubuntu@IP 'docker inspect node-app | grep -A5 -i environment'
  ```
- **Solution:** fix the crash per logs (e.g. `EADDRINUSE` → free the port);
  verify `BUILD_VERSION`/`PORT` env; confirm image actually contains `server.js`
  (`docker run --rm node-app:83 ls /usr/src/app`).
- **Prevention:** the Dockerfile HEALTHCHECK + deploy.sh's retry loop catch this
  before marking the deploy successful.

---

## 7. 502 Bad Gateway from Nginx

- **Problem:** browser shows `502 Bad Gateway` at `http://IP/`.
- **Cause:** upstream (container on 127.0.0.1:3000) is down, slow, or not bound
  where the proxy config expects.
- **Diagnose:**
  ```bash
  ssh ubuntu@IP 'docker ps; curl -s http://127.0.0.1:3000/health'
  ssh ubuntu@IP 'sudo tail -30 /var/log/nginx/error.log'
  ssh ubuntu@IP 'sudo nginx -t'
  ```
- **Solution:** restart the container (`bash /opt/devops/deploy.sh` or manual
  `docker run`); if the app is healthy on 3000 but Nginx 502s, fix the
  `upstream`/`proxy_pass` in `app-proxy.conf` and `sudo systemctl reload nginx`.
- **Prevention:** keep the Nginx config in the repo (done), test `nginx -t` in the
  deploy, and make the health check part of the pipeline.

---

## 8. Health check failing from Jenkins

- **Problem:** the pipeline's Health Check stage fails though the app looks fine.
- **Cause:** the instance's public IP changed (stop/start), the SG 80 rule is
  missing/too narrow, Nginx is down, or the container didn't bind.
- **Diagnose:**
  ```bash
  aws ec2 describe-instances --instance-ids <id> --query 'Reservations[].Instances[].PublicIpAddress'
  curl -sv http://EC2_IP/health     # -v shows connect vs HTTP errors
  ```
- **Solution:** update `EC2_PUBLIC_IP` in Jenkins (or use an Elastic IP); confirm
  the container is `Up`; check Nginx.
- **Prevention:** health check runs BOTH from the host (127.0.0.1) and from Jenkins
  (public IP) to separate "container broken" from "network/firewall broken".

---

## 9. Docker image too large for transfer

- **Problem:** `docker save | ssh ... docker load` is slow or times out.
- **Cause:** large base images/unnecessary build context; slow instance type or
  upstream bandwidth.
- **Diagnose:** `docker images node-app` shows e.g. `1.2GB`; `ls -lh` the tar.
- **Solution:** use `node:20-alpine` (already), add `.dockerignore` (done), flatten
  with `--squash` if needed, or switch to **registry push/pull** (ECR/Docker Hub)
  — typically much faster than piping a tar over SSH.
- **Prevention:** keep images lean; prefer registry mode in production
  (`USE_REGISTRY=true`).

---

## 10. AWS credential error

- **Problem:** `aws ec2 ...` CLI fails with `Unable to locate credentials` or
  `ExpiredToken` / `InvalidAccessKeyId`.
- **Cause:** `aws configure` never run, keys rotated, or a stale profile.
- **Diagnose:** `aws sts get-caller-identity`; `echo $AWS_*` env vars.
- **Solution:** `aws configure` with a valid key/secret/region; or
  `aws configure --profile devops` and pass `--profile devops`; rotate keys if
  they were exposed.
- **Prevention:** use short-lived credentials (SSO) where possible; store the
  profile name in the README; never put keys in the repo.

---

## 11. Git auth failure in Jenkins

- **Problem:** Checkout stage fails with `Authentication failed` / `could not read Username for 'https://github.com'`.
- **Cause:** the `github-creds` credential is missing, wrong, or not attached to
  the job's SCM config.
- **Diagnose:** Console Output of the Checkout stage; test the credential with
  `git ls-remote https://github.com/<user>/<repo>.git` using a PAT.
- **Solution:** add/replace the **Username with password** credential (username =
  your GitHub user, password = **PAT with `repo` scope**, not the login password);
  select it in the job's Git SCM.
- **Prevention:** document PAT scope requirements in the README; create the
  credential BEFORE the first Build Now.

---

## 12. Instance stopped / "instance is in a stopped state" (cost)

- **Problem:** the app is down and `describe-instances` shows `stopped`.
- **Cause:** manual stop, auto-scaling/policy action, or an expired spot request.
- **Diagnose:** `aws ec2 describe-instances --instance-ids <id> --query 'Reservations[].Instances[].StateReason'`.
- **Solution:** `aws ec2 start-instances --instance-ids <id>`, wait for
  `State: running`, and **re-check the public IP** (it likely changed).
- **Prevention:** use an Elastic IP; stop instances intentionally (cheaper than
  terminate) and document IP drift in the deploy notes.

---

## 13. Wrong region / resources not found

- **Problem:** `run-instances`/`describe-security-groups` returns "not found" for
  things that exist in the console.
- **Cause:** AWS CLI is pointed at a different region than the console/resources.
- **Diagnose:** `aws configure list` (shows region); `aws ec2 describe-regions`.
- **Solution:** add `--region us-east-1` (or your chosen region) to every command,
  or set the env `AWS_DEFAULT_REGION`.
- **Prevention:** create all resources in ONE region; put the region in the
  README and in `aws configure`.
