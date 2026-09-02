# Commands Cheat Sheet

All commands assume:
- `~/.ssh/devops-key.pem` is your EC2 key pair (chmod 400 on Linux/macOS).
- `EC2_IP` below is your instance's public IPv4 address.
- `BUILD_NUM` is the Jenkins build number used as the image tag.

Format: COMMAND / PURPOSE / WHAT IT DOES / EXPECTED OUTPUT / COMMON ERROR / FIX

---

## 1. Launch an EC2 instance

aws ec2 run-instances --image-id ami-0abcdef1234567890 --count 1 --instance-type t2.micro --key-name devops-key --security-group-ids sg-0123456789abcdef0 --subnet-id subnet-0123456789abcdef0 --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=devops-node-app}]' --user-data file://../scripts/ec2-bootstrap.sh

**PURPOSE**
Create the Ubuntu server that will run Docker + Nginx + the app container.

**WHAT IT DOES**
Launches a VM from an AMI, attaches your security group + key pair, and runs the
user-data bootstrap script on first boot (installs Docker, pulls nginx image).

**EXPECTED OUTPUT**
JSON object with `Instances[0].InstanceId` (e.g. `i-0abc123def456`), state
`pending`, and `Placement.AvailabilityZone`.

**COMMON ERROR**
`InvalidKeyPair.NotFound` or `InvalidGroup.NotFound`.

**FIX**
Verify the key pair name and security group ID exist in the same region — use
`aws ec2 describe-key-pairs` and `aws ec2 describe-security-groups` first.

---

## 2. List instances

aws ec2 describe-instances --filters Name=tag:Name,Values=devops-node-app --query 'Reservations[].Instances[].{Id:InstanceId,State:State.Name,PublicIp:PublicIpAddress}' --output table

**PURPOSE**
Find your instance's ID, state, and public IP.

**WHAT IT DOES**
Queries EC2 and prints a table of ID / state / public IP for tagged instances.

**EXPECTED OUTPUT**
A table row like `| i-0abc123def456 | running | 54.23.45.67 |`.

**COMMON ERROR**
Empty output (no instances matched) or `InvalidParameterValue` on the filter.

**FIX**
Double-check the tag key/value. Run without `--filters` to confirm the instance
exists at all.

---

## 3. Describe instance details

aws ec2 describe-instances --instance-ids i-0abc123def456

**PURPOSE**
Get full JSON details: public IP, security groups, AMI, type, and state.

**WHAT IT DOES**
Returns the complete `Reservation` object for the instance.

**EXPECTED OUTPUT**
JSON including `State.Name: "running"`, `PublicIpAddress`, and `SecurityGroups`.

**COMMON ERROR**
`InvalidInstanceID.Malformed` (wrong ID) or `UnauthorizedOperation` (no IAM perms).

**FIX**
Copy the ID exactly from the console/output. Add EC2 read permissions to your IAM
user or use a role.

---

## 4. Stop an instance

aws ec2 stop-instances --instance-ids i-0abc123def456

**PURPOSE**
Stop billing (CPU/RAM) but keep the disk — good for overnight cost savings.

**WHAT IT DOES**
Sends an ACPI shutdown; the instance enters `stopping` then `stopped`. EBS volumes
persist, so the OS + installed Docker remain.

**EXPECTED OUTPUT**
JSON with `CurrentState.Name: "stopping"`.

**COMMON ERROR**
`UnauthorizedOperation` (no permission) or a stop hung in `stopping`.

**FIX**
Check IAM permissions. For a hung stop, force it via the console
(Stop → Wait for stop; never delete volumes).

---

## 5. Start an instance

aws ec2 start-instances --instance-ids i-0abc123def456

**PURPOSE**
Bring a stopped instance back online (e.g. next morning).

**WHAT IT DOES**
Boots the VM; the public IP may CHANGE if it was a normal public IP (non-Elastic).
Wait for `State: running` before deploying.

**EXPECTED OUTPUT**
JSON with `PreviousState.Name: "stopped"`, `CurrentState.Name: "pending"`.

**COMMON ERROR**
`IncorrectInstanceState` when starting an instance that was terminated.

**FIX**
Check `describe-instances` — a terminated instance can never be started; launch a
new one from the AMI.

---

## 6. Terminate an instance (cost cleanup!)

aws ec2 terminate-instances --instance-ids i-0abc123def456

**PURPOSE**
Permanently delete the VM and stop ALL charges (EBS volumes are deleted too).

**WHAT IT DOES**
Shuts down and marks `terminated`. The instance and its root volume are gone —
irreversible unless you had a snapshot or AMI.

**EXPECTED OUTPUT**
JSON with `CurrentState.Name: "shutting-down"` then `"terminated"`.

**COMMON ERROR**
`UnauthorizedOperation` or realizing you terminated the wrong instance.

**FIX**
Confirm the instance ID (tag it with Name to be sure). Grant only the specific
instance termination permission via IAM if needed.

---

## 7. List security group rules

aws ec2 describe-security-groups --group-ids sg-0123456789abcdef0 --query 'SecurityGroups[].IpPermissions[]'

**PURPOSE**
Verify your firewall rules (SSH from your IP, HTTP from everywhere).

**WHAT IT DOES**
Prints the inbound (IpPermissions) rule definitions for the group.

**EXPECTED OUTPUT**
JSON array showing `IpProtocol: "tcp"`, `FromPort: 22`, `ToPort: 22`, and the
CIDR `IpRanges[].CidrIp`.

**COMMON ERROR**
`InvalidGroup.NotFound` — group doesn't exist or is in another region.

**FIX**
Use `aws ec2 describe-security-groups` without `--group-ids` to list all groups
and match the correct region (`--region`).

---

## 8. SSH into the instance

ssh -i ~/.ssh/devops-key.pem ubuntu@EC2_IP

**PURPOSE**
Get a shell on the EC2 host for troubleshooting and manual verification.

**WHAT IT DOES**
Connects to port 22 using the private key, authenticating as user `ubuntu`
(the default on Ubuntu AMIs). First connect asks to accept the host key.

**EXPECTED OUTPUT**
`Welcome to Ubuntu ...` banner and a shell prompt like `ubuntu@ip-...:~$`.

**COMMON ERROR**
`Permissions 0664 for 'devops-key.pem' are too open` (Windows-scp'd file) or
`Permission denied (publickey)`.

**FIX**
On Linux/macOS: `chmod 400 ~/.ssh/devops-key.pem`. Verify you're using `ubuntu@`
and the *public* IP (not a private one).

---

## 9. Copy a file to the instance

scp -i ~/.ssh/devops-key.pem scripts/deploy.sh ubuntu@EC2_IP:/opt/devops/

**PURPOSE**
Transfer deploy/rollback/healthcheck scripts (and the image archive) to EC2.

**WHAT IT DOES**
Uses the same key-pair auth as SSH to copy a file over an encrypted channel.

**EXPECTED OUTPUT**
A progress bar and `deploy.sh 100% 512 1.2MB/s 00:00`.

**COMMON ERROR**
`Permission denied (publickey)` or `No such file or directory` for the target.

**FIX**
Create the remote dir first (`ssh ... 'mkdir -p /opt/devops'`). Fix key perms and
confirm the key name matches the one attached to the instance.

---

## 10. Save a Docker image to a tar archive

docker save node-app:83 -o app-image.tar

**PURPOSE**
Bundle a local image into one file so it can be shipped to EC2 without a registry.

**WHAT IT DOES**
Serializes all image layers + metadata into `app-image.tar` (this is what the
Jenkinsfile pipes to `ssh ... docker load`).

**EXPECTED OUTPUT**
No stdout on success; the file appears (`ls -lh app-image.tar`).

**COMMON ERROR**
`Error response from daemon: No such image: node-app:83`.

**FIX**
Verify the tag exists with `docker images` and build/push that exact tag first.

---

## 11. Load a Docker image from a tar archive

docker load -i app-image.tar

**PURPOSE**
Import the image on EC2 after transferring the tar (registry-free deploy).

**WHAT IT DOES**
Reads the tar and registers the image layers into the local Docker store.

**EXPECTED OUTPUT**
`Loaded image: node-app:83` (or `Loaded image ID: sha256:...`).

**COMMON ERROR**
`Error processing tar file` — truncated/corrupt archive from an interrupted scp.

**FIX**
Re-send the archive (check file size with `ls -l` on both ends), or use the
streaming `docker save IMAGE | ssh ... 'docker load'` pattern.

---

## 12. Run the app container

docker run -d --name node-app --restart unless-stopped -p 127.0.0.1:3000:3000 -e BUILD_VERSION=83 -e PORT=3000 node-app:83

**PURPOSE**
Start the app container on EC2 bound to localhost:3000 so only Nginx on port 80
is public.

**WHAT IT DOES**
Creates and starts a detached container with auto-restart, publishes
host:3000 → container:3000, and sets the build version env.

**EXPECTED OUTPUT**
A container ID hash printed on stdout; `docker ps` shows `node-app` with status
`Up` and `0.0.0.0:3000->3000/tcp`-style mapping.

**COMMON ERROR**
`port is already allocated` or `Bind for 0.0.0.0:3000 failed`.

**FIX**
A previous container holds the port — `docker ps -a` and `docker rm -f node-app`,
or choose a different host port.

---

## 13. List running containers

docker ps

**PURPOSE**
Confirm the app container is up, see ports and image/version.

**WHAT IT DOES**
Prints running containers: ID, image, command, status, ports, name.

**EXPECTED OUTPUT**
A table row `node-app ... Up 3 minutes ... 127.0.0.1:3000->3000/tcp`.

**COMMON ERROR**
Empty list when you expected a container.

**FIX**
Run `docker ps -a` (includes stopped ones) and `docker logs node-app` to see why
it exited.

---

## 14. Check the app health endpoint

curl -s http://EC2_IP/health

**PURPOSE**
Verify end-to-end: internet → security group :80 → Nginx → container :3000 → app.

**WHAT IT DOES**
Makes an HTTP GET to Nginx, which proxies to the app; prints the JSON.

**EXPECTED OUTPUT**
`{"status":"ok","service":"node-app","buildVersion":"83","uptimeSeconds":12,...}`.

**COMMON ERROR**
`curl: (7) Failed to connect ... Connection refused` or a 502/504 from Nginx.

**FIX**
Check security group 80 rule, Nginx `sudo systemctl status nginx`, and the
container `docker ps` + `docker logs`.

---

## 15. View container logs

docker logs --tail 100 node-app

**PURPOSE**
Debug container crashes or startup errors from the EC2 host.

**WHAT IT DOES**
Prints the last 100 stdout/stderr lines of the container.

**EXPECTED OUTPUT**
The app's `[server] listening on 0.0.0.0:3000 (build: 83)` line plus any errors.

**COMMON ERROR**
`Error response from daemon: No such container: node-app`.

**FIX**
Run `docker ps -a | grep node-app` — the name may differ or the container was
removed by rollback.

---

## 16. Trigger a Jenkins build via the REST API

curl -X POST -u "jenkins-user:JENKINS_API_TOKEN" http://JENKINS_HOST:8080/job/devops-node-app/build

**PURPOSE**
Kick the pipeline remotely (also what a GitHub webhook effectively does).

**WHAT IT DOES**
Sends an HTTP POST to Jenkins; Jenkins enqueues a build of the job. Requires a
Jenkins user + API token (CSRF crumb for newer Jenkins with `crumbIsSensitive`).

**EXPECTED OUTPUT**
HTTP `201 Created` with an empty body (the build starts asynchronously).

**COMMON ERROR**
`403 No valid crumb was included` or `401 Authentication failed`.

**FIX**
Fetch a crumb first: `curl -u user:token http://JENKINS:8080/crumbIssuer/api/json`,
then POST with `-H "Jenkins-Crumb: <crumb>"`. For 401 use a real API token, not
the login password.

---

## 17. Parse JSON with jq

curl -s http://EC2_IP/health | jq '.status, .buildVersion'

**PURPOSE**
Extract specific fields from JSON in scripts and the terminal.

**WHAT IT DOES**
Pipes the health JSON through jq, printing the values of `.status` and
`.buildVersion`.

**EXPECTED OUTPUT**
`"ok"` and `"83"` on two lines.

**COMMON ERROR**
`jq: error ... Cannot index string with "status"` when the response is HTML
(Nginx error page) not JSON.

**FIX**
Inspect the raw body with `curl -s http://EC2_IP/health` — a 502 page means the
container is down, not that jq is broken.

---

## 18. Fix key permissions

chmod 400 ~/.ssh/devops-key.pem

**PURPOSE**
Make the private key readable only by your user so OpenSSH accepts it.

**WHAT IT DOES**
Removes group/other read bits, setting mode `0400` (owner read-only). OpenSSH
refuses keys that are too open.

**EXPECTED OUTPUT**
No output; verify with `ls -l ~/.ssh/devops-key.pem` → `-r--------`.

**COMMON ERROR**
`Permissions 0664 for '...pem' are too open` still appearing.

**FIX**
Run `chmod 400` (not `600` is also fine; just ensure no group/other perms). On
Windows, keep the key in a user-only folder and use `icacls` to restrict ACLs.
