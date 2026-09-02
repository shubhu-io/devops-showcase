# Screenshots

This folder intentionally contains **no generated/fabricated images**. Screenshots
must be captured from your own environment so every claim is verifiable.

Add your own captures using the naming convention `NN-name.png` (e.g. `01-ec2-console.png`).

## Required captures (in suggested order)

| # | What to capture | Where | What to look for |
|---|-----------------|-------|------------------|
| 1 | EC2 instance list | AWS Console > EC2 > Instances | Instance state `running`, valid IPv4 public IP, correct name tag |
| 2 | Security group inbound rules | AWS Console > EC2 > Security Groups > Inbound rules | SSH `22` from `YOUR_IP/32`, HTTP `80` from `0.0.0.0/0` |
| 3 | Security group outbound rules | AWS Console > EC2 > Security Groups > Outbound rules | `0.0.0.0/0` allowed (default) |
| 4 | Key pair download prompt | AWS Console > EC2 > Key Pairs | `.pem` file downloaded to `~/.ssh/` |
| 5 | SSH session | Local terminal | `ssh -i ~/.ssh/your-key.pem ubuntu@IP` lands at a shell prompt |
| 6 | Docker running on EC2 | EC2 SSH session | `docker ps`, `systemctl status docker` show active containers/daemon |
| 7 | Nginx config test | EC2 SSH session | `sudo nginx -t` reports `syntax is ok` |
| 8 | Jenkins pipeline blue run | Jenkins job page / Blue Ocean | All stages green: Checkout, Test, Docker Build, Transfer, Deploy, Health Check |
| 9 | Deploy stage console output | Jenkins > Build #N > Console Output | `[deploy] Health check passed` and the exact `docker run` command |
| 10 | App web page | Browser → `http://EC2_PUBLIC_IP/` | "App is Running" page showing the build version |
| 11 | `/health` JSON | Browser/curl → `http://EC2_PUBLIC_IP/health` | `{"status":"ok", ...}` with build version |
| 12 | Rollback demo | Terminal / Jenkins console | `rollback.sh` output showing previous image restored and healthy |
| 13 | Trivy scan (optional) | Jenkins console of Security Scan stage | Scan summary line (`Total: X (UNKNOWN:0...)`) |

## Markdown placeholder

Once captured, reference them like this in the README:

```markdown
![EC2 console](../screenshots/01-ec2-console.png)
```
