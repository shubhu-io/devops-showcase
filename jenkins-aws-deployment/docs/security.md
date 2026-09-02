# Security Guide

Security is a first-class concern for any internet-facing pipeline. This project
has zero secrets committed; below is every rule that keeps it that way.

## 1. Never store AWS credentials in the repo

- `.gitignore` excludes `.env`, `.env.*`, and `*.pem`.
- AWS credentials live in `~/.aws/credentials` (local CLI) or IAM roles (EC2),
  **never** in code, the Jenkinsfile, or docs.
- If a key ever leaks: rotate it immediately in IAM (`Access keys → Delete`).

## 2. IAM least privilege

- Don't use your root account. Create an IAM user with only what it needs.
- Minimal policy for this project's CLI usage:
  - `ec2:RunInstances`, `ec2:DescribeInstances`, `ec2:StopInstances`,
    `ec2:StartInstances`, `ec2:TerminateInstances`,
    `ec2:CreateKeyPair`, `ec2:CreateSecurityGroup`,
    `ec2:AuthorizeSecurityGroupIngress`, `ec2:DescribeSecurityGroups`,
    `ec2:DescribeImages`.
- Even better: attach a scoped policy, or use temporary credentials
  (AWS SSO / STS) instead of long-lived keys.
- On EC2, use an **instance profile/role** for any AWS API calls the host makes —
  never paste keys into the instance.

## 3. Security group minimum exposure

| Port | Source | Rationale |
|---|---|---|
| 22 | `YOUR_IP/32` only | SSH from your static IP; open 0.0.0.0/0 only if required, and pair with fail2ban |
| 80 | `0.0.0.0/0` | the app must be public |
| 8080 (Jenkins) | your IP only | never expose Jenkins admin to the internet unauthenticated |

- The host has `ufw` rules as defense-in-depth, but the security group is the
  real boundary — change it in AWS, not just in `ufw`.

## 4. SSH hardening

- Key-pair auth only — no passwords. This is automatic with EC2 key pairs.
- Disable password auth explicitly on the host:
  ```
  sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  sudo systemctl restart ssh
  ```
- Install **fail2ban** to block repeated brute-force attempts:
  ```
  sudo apt-get install -y fail2ban
  sudo systemctl enable --now fail2ban
  ```
- Keep `~/.ssh/authorized_keys` trimmed to real admins.
- Use a non-root user (`ubuntu` default) and `sudo` only when needed.
- Keep the system patched: `sudo apt-get upgrade -y` in the bootstrap script.

## 5. Jenkins credential store

- All secrets go through Jenkins Credentials, referenced by ID:
  - `ec2-key` — SSH private key to EC2 (used by `sshagent`).
  - `github-creds` — repo checkout auth.
  - `dockerhub` — registry login (only when `USE_REGISTRY=true`).
- Never type a real secret into a `sh` step literal; use `credentials()` /
  `withCredentials()` bindings which mask values in logs.
- Restrict who can see/manage the credential store; enable "mask passwords" and
  credential-scoped log masking.

## 6. key.pem handling

- Store in `~/.ssh/` with `chmod 400` (owner-only).
- Never commit, screenshot, or paste `.pem` contents into logs/issues.
- The key gives full shell access — treat it like a password.
- On Windows, restrict ACLs (`icacls`) to your user; the default inherited ACLs
  break SSH anyway.
- Generate a fresh key per environment; don't share one across projects.

## 7. Docker image scanning

- The pipeline runs **Trivy** on every image (HIGH/CRITICAL severities) and
  fails loudly if issues are found when the binary is present.
- Run the app as a non-root user (`USER appuser` in the Dockerfile).
- Use pinned base image tags (`node:20-alpine`) and update them regularly.
- Prefer small base images (alpine) to shrink the attack surface.
- `docker save` image archives over the wire are SSH-encrypted — never push a
  `docker save` tar through an unencrypted channel.

## 8. General hygiene checklist

- [ ] No secrets in the repo (`git log` clean of `.env`, `.pem`).
- [ ] IAM user scoped to EC2 only.
- [ ] SG: 22 from your IP only, 80 public, 8080 restricted.
- [ ] Password auth disabled in sshd; fail2ban active.
- [ ] Jenkins creds: `ec2-key`, `github-creds` created with unique IDs.
- [ ] Container runs as non-root, image scanned by Trivy.
- [ ] Instances terminated after testing (see README cost section).
