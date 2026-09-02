# Troubleshooting

Each entry uses the same structure:

- **Problem** - the symptom you see
- **Cause** - why it happens
- **How to diagnose** - commands / where to look
- **Solution** - the fix
- **Prevention** - how to avoid it next time

---

## 1. AWS credential error ("no valid credential sources")

- **Problem**: `terraform plan`/`apply` fails with `no valid credential sources
  for Terraform Provider found`.
- **Cause**: No access key in `~/.aws/credentials` and no `AWS_ACCESS_KEY_ID` /
  `AWS_SECRET_ACCESS_KEY` env vars set.
- **How to diagnose**: Run `aws sts get-caller-identity`. If it fails with
  `Unable to locate credentials`, you have no configured credentials.
- **Solution**: Run `aws configure` with an access key that has EC2/VPC/IAM
  permissions. For automation, use env vars or an EC2 instance profile.
- **Prevention**: Document credential setup in `docs/setup.md`; use named
  profiles (`aws configure --profile dev`) and `export AWS_PROFILE=dev`.

---

## 2. Terraform state error (state locked / invalid)

- **Problem**: `Error: Error acquiring the state lock` or
  `Error: unsupported state format`.
- **Cause**: Another `terraform` process holds the lock (e.g. a hung `apply`), or
  the state file is corrupted / a different Terraform version wrote it.
- **How to diagnose**: `terraform force-unlock <lock-id>` shows who holds the
  lock. `terraform state list` fails if state is corrupt.
- **Solution**: Find and stop the other process (check running terminal / CI),
  then `terraform force-unlock <lock-id>`. For corrupt local state, restore from
  a backup copy of `terraform.tfstate`.
- **Prevention**: Don't run two applies concurrently on local state; in
  production use a remote backend with DynamoDB locking. Back up
  `terraform.tfstate`.

---

## 3. Resource already exists / 400 error

- **Problem**: `Error: creating Security Group: InvalidGroup.Duplicate` (or
  similar 400 errors) on `apply`.
- **Cause**: A resource with the same name exists outside of Terraform state -
  e.g. a previous run that was deleted in the console, or a resource created
  manually.
- **How to diagnose**: Check the AWS console for the object by name; compare
  `terraform state list` with what exists in AWS.
- **Solution**: Either delete the AWS-side duplicate, or adopt it with
  `terraform import <address> <id>` so Terraform manages it.
- **Prevention**: Destroy before deleting in the console; use unique
  `project_name` / `environment` name prefixes.

---

## 4. Security group rule not applied

- **Problem**: Traffic allowed by your `security-group.tf` is still blocked.
- **Cause**: The instance is using a different security group, or the rule was
  edited after the instance launch, or `terraform apply` never ran after the
  change.
- **How to diagnose**: Console → EC2 → instance → Security tab. `terraform show`
  and check `vpc_security_group_ids`. In AWS console, inspect the SG inbound
  rules.
- **Solution**: Confirm the SG in the console matches the config, then
  `terraform apply`. Replace `0.0.0.0/0` with your real CIDR if you edited it.
- **Prevention**: Check the SG *before* reaching for the instance; make SG
  changes visible via `terraform plan`.

---

## 5. EC2 can't be reached (SSH timeout)

- **Problem**: `ssh -i <key>.pem ubuntu@<ip>` hangs then
  `Connection timed out`.
- **Cause**: `allowed_ssh_cidr` does not match your current public IP, port 22
  is filtered, the instance is in a private subnet without NAT, or the SG was
  left with the `your-ip/32` placeholder.
- **How to diagnose**: `aws ec2 describe-instances` for instance state and IP;
  `curl http://<public_ip>` (if port 80 works, networking is fine and it's an
  SSH-only issue). Your IP may have changed - compare with `curl ifconfig.me`.
- **Solution**: Update `allowed_ssh_cidr` to your current IP with `/32`,
  `terraform apply`, retry. Alternatively use SSM Session Manager (no port 22
  required) - we attached `AmazonSSMManagedInstanceCore` already.
- **Prevention**: Use SSM as primary access; keep the SG locked to your IP.

---

## 6. User data not running

- **Problem**: Instance is up but the app/nginx is not running and port 80 is
  dead.
- **Cause**: Script error, wrong AMI user, or user-data ran before packages
  were available.
- **How to diagnose**: SSH in and check the log:
  `sudo journalctl -u cloud-final --no-pager | tail -50` and
  `cat /tmp/user-data-complete.log`. The script's `set -euo pipefail` means any
  error stops it silently after the failed line.
- **Solution**: Fix the script, then force a re-run: change a line in
  `user-data.sh` (with `user_data_replace_on_change = true`, `terraform apply`
  replaces the instance), or manually run
  `sudo /var/lib/cloud/instance/scripts/part-001` on the box for a quick retest.
- **Prevention**: Keep the script idempotent; add `set -x` during debugging;
  read logs before redeploying.

---

## 7. AMI not found

- **Problem**: `Error: Your query returned no results` on `data.aws_ami.ubuntu`.
- **Cause**: The AMI name filter doesn't match, the owner ID changed, the region
  has no matching AMI, or you filtered on an architecture not offered there.
- **How to diagnose**: Manually query:
  `aws ec2 describe-images --owners 099720109477 --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" --query 'Images[].{Name:Name,ImageId:ImageId}'`.
- **Solution**: Widen/update the filter to the current Ubuntu 24.04 naming, or
  pin a known-good AMI in `variables.tf`.
- **Prevention**: Keep the filter loose (`most_recent = true` helps); verify
  the name pattern on AWS before running.

---

## 8. Plan shows changes you didn't make (drift)

- **Problem**: `terraform plan` wants to change resources you haven't touched.
- **Cause**: Someone edited resources in the AWS console (drift), or config
  defaults changed, or `default_tags`/name prefixes changed.
- **How to diagnose**: `terraform plan -detailed-exitcode`; diff the plan with
  what you last applied. `terraform state show <address>` shows what state
  thinks exists.
- **Solution**: Review the diff. If the AWS-side change is wanted, import or
  keep it and update config; if not, correct the resource in the console or
  re-apply.
- **Prevention**: Enforce "no console edits" via IAM policies / `aws_guardrails`;
  plan before every apply; make changes through Terraform only.

---

## 9. Subnet not found

- **Problem**: `Error: creating EC2 Instance: ... subnet ID 'subnet-xxx' does
  not exist`.
- **Cause**: `aws_subnet.public.id` references a deleted/other-region subnet, or
  state is stale.
- **How to diagnose**: `aws ec2 describe-subnets` and compare with
  `terraform state show aws_subnet.public`.
- **Solution**: `terraform plan` should recreate a missing subnet. If state is
  stale, `terraform state rm aws_subnet.public` then re-apply, or import the
  real subnet ID.
- **Prevention**: Don't delete subnets in the console; use the 
  `${project_name}-${environment}-public-subnet` name convention to spot
  mismatches.

---

## 10. Key pair not found

- **Problem**: `Error: creating EC2 Instance: ... KeyPair 'terraform-demo' not
  found` on apply.
- **Cause**: `key_name` doesn't match a key pair in this region, or the pair was
  deleted.
- **How to diagnose**: `aws ec2 describe-key-pairs --region us-east-1`.
- **Solution**: Create the key pair in the region and set `key_name` in
  `terraform.tfvars`, or use a different existing pair.
- **Prevention**: Note that key pairs are region-specific; document creation in
  `docs/setup.md`.

---

## 11. InsufficientInstanceCapacity

- **Problem**: `Error: creating EC2 Instance: InsufficientInstanceCapacity`.
- **Cause**: AWS has no capacity for that instance type in that AZ right now
  (very common for t2.micro/t3.micro in busy regions).
- **How to diagnose**: Check the exact AZ in the error; retry later.
- **Solution**: Wait and retry, change AZ (`public_subnet_cidr` / AZ selection),
  or change `instance_type` (e.g. t3.micro → t2.micro → t3.small).
- **Prevention**: Use a flexible instance type; retry during off-peak hours.

---

## 12. "VPC/EC2 not enabled in region"

- **Problem**: `Error: ... EC2 features unavailable for this region` or VPC
  resource 400 errors.
- **Cause**: The account has no default VPC, EC2 is not enabled, or the region
  is new/restricted for your account.
- **How to diagnose**: `aws ec2 describe-regions`; check `terraform.tfvars`
  `region` value; `aws sts get-caller-identity` to confirm the account.
- **Solution**: Use a region that supports EC2, or enable the service in the
  AWS console (account-level, sometimes support-required). Ensure `region`
  matches where the key pair lives.
- **Prevention**: Verify region availability before applying; keep all
  resources in one region.

---

## 13. Destroy hanging

- **Problem**: `terraform destroy` never completes (e.g. stuck on
  `aws_instance.web` or a VPC dependency).
- **Cause**: A dependent object that Terraform doesn't manage (an ENI, an
  Elastic IP, a manually attached SG), or AWS-side deletion lag.
- **How to diagnose**: Watch which resource is stuck; check the AWS console for
  dangling dependencies (e.g. instance still terminating).
- **Solution**: Terminate the stragglers in the console (terminate instance,
  release EIP, detach ENI), then re-run `terraform destroy`.
- **Prevention**: Don't attach unmanaged resources (EIPs, volumes) outside
  Terraform; run destroy when you know nothing else depends on the stack.

---

## 14. `Error: Unsupported argument`

- **Problem**: `terraform validate`/`plan` fails with
  `An argument named "..." is not expected here`.
- **Cause**: A typo, an argument that doesn't exist for that resource, or a
  provider version that doesn't support the argument.
- **How to diagnose**: Check the exact resource/argument name against the
  provider docs for the version in `versions.tf`.
- **Solution**: Fix/remove the argument. Update the provider
  (`terraform providers` to see versions) if the argument needs a newer release.
- **Prevention**: Run `terraform validate` after every edit; copy argument names
  from provider docs.

---

## 15. Backend S3 access denied

- **Problem**: After enabling an S3 backend, `terraform init` fails with
  `AccessDenied` on the bucket/state key.
- **Cause**: The credentials can't read/write the S3 bucket, or the bucket
  doesn't exist in that region/account.
- **How to diagnose**: `aws s3 ls s3://<bucket>` to test access with the same
  credentials.
- **Solution**: Fix the IAM policy (allow `s3:GetObject`/`s3:PutObject` on
  `bucket/terraform.tfstate`, `s3:ListBucket` on the bucket), create the bucket,
  or correct the `backend "s3"` config.
- **Prevention**: Verify S3 access before switching backends; use
  `state_exists`/preflight checks in CI.
