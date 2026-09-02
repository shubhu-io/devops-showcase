# Security

Security principles applied in this project, plus rules to follow when running it.

## 1. Secrets never in the repo

- `terraform.tfvars` (real IPs, names) is gitignored - only
  `terraform.tfvars.example` with placeholders is committed.
- `*.pem`, `*.key`, `.env` are gitignored. Private keys never leave your machine.
- `*.tfstate` is gitignored - **state can contain secrets** (passwords,
  connection strings). In production use encrypted remote state (S3 SSE +
  restricted access) rather than local files.

## 2. Least-privilege IAM

- The EC2 instance gets a **role + instance profile**, not access keys. Its
  credentials are short-lived, rotated by STS, and revoked instantly if the role
  is removed.
- Attached policies: `AmazonSSMManagedInstanceCore` (keyless admin access) and a
  minimal inline policy granting **only** `s3:GetObject` on one placeholder
  bucket.
- Rule: give a role exactly the permissions the workload needs. Audit with
  `aws iam list-attached-role-policies --role-name <name>`.

## 3. Security groups - expose only what's needed

- SSH (22): restricted to `allowed_ssh_cidr` = **your IP only** (`your-ip/32`
  default). Never open SSH to `0.0.0.0/0`.
- HTTP (80) / HTTPS (443): open to the internet because that's the app's job.
- The app port (3000) is **not** exposed publicly - only Nginx on the host talks
  to it via `127.0.0.1`.

## 4. Secrets at runtime

- No credentials are baked into `user-data.sh` or the AMI.
- For real secrets (DB passwords, API keys), store them in **AWS SSM Parameter
  Store** or **Secrets Manager** and fetch them in the app or at bootstrap via
  the IAM role (e.g. `aws ssm get-parameter --with-decryption`). Keep rotation
  and audit logging for free.

## 5. Access hygiene

- Use `aws sts get-caller-identity` to confirm which account you're acting as.
- Prefer named CLI profiles per environment (`aws configure --profile dev`) and
  `export AWS_PROFILE=dev`; don't share a root user - create IAM users/groups.
- Prefer **SSM Session Manager** over SSH: no open port 22 at all, IAM-based
  authorization, session logs via CloudTrail.

## 6. Extra hardening (future work)

- Add **NACLs** as a second layer of defense.
- Terminate **HTTP with TLS** (ACM cert + ALB or certbot on Nginx) - see
  `../README.md` "Future Improvements".
- Enable **CloudTrail** and **GuardDuty** for audit and threat detection.
- Make the S3 bucket real (private) and put only the configs the app reads.

## 7. Destroy to zero

- Anything left running bills you and may be exposed. `terraform destroy` after
  the demo, then verify with the EC2 describe command in `deployment.md`.
