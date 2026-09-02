# Commands Cheat Sheet

All commands assume you are in the `terraform/` directory unless noted.
`<...>` means replace with your value. 18+ commands, each with purpose, behaviour,
expected output, common error, and fix.

---

## 1. `terraform --version`

↓ **PURPOSE**
Verify Terraform is installed and check its version.

↓ **WHAT IT DOES**
Prints the Terraform version and the versions of any installed providers.

↓ **EXPECTED OUTPUT**
```
Terraform v1.14.9
on windows_386
```

↓ **COMMON ERROR**
`terraform: command not found`

↓ **FIX**
Install Terraform (see `../docs/setup.md`). On Linux/macOS use
`brew install terraform` or download from https://developer.hashicorp.com/terraform/install and add it to `PATH`.

---

## 2. `terraform init`

↓ **PURPOSE**
Initialize the working directory and download provider plugins.

↓ **WHAT IT DOES**
Reads `versions.tf`/`provider.tf`, downloads `hashicorp/aws`, creates
`.terraform/`, writes `.terraform.lock.hcl`, and configures the backend.

↓ **EXPECTED OUTPUT**
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.100.0...
Terraform has been successfully initialized!
```

↓ **COMMON ERROR**
`Error: Failed to query available provider packages` (network blocked) or
`Could not retrieve the list of available versions for provider hashicorp/aws`.

↓ **FIX**
Check internet access / proxy. Re-run `terraform init` when on the network.
Also re-run `terraform init` after ANY change to `versions.tf`, `provider.tf`, or
adding a module/backend.

---

## 3. `terraform fmt -recursive`

↓ **PURPOSE**
Format all HCL files in the standard canonical style.

↓ **WHAT IT DOES**
Rewrites indentation, alignment, and line wrapping across every `.tf`/`.tfvars`
file in the directory tree. Does not change semantics.

↓ **EXPECTED OUTPUT**
No output and a clean exit if already formatted. If it prints filenames
(e.g. `ec2.tf`), those files were re-formatted.

↓ **COMMON ERROR**
`Error: Invalid legacy provider address` — rarely seen; usually means stale config.

↓ **FIX**
Files were changed - run `terraform validate` afterwards. Use
`terraform fmt -recursive -check` to just verify formatting without rewriting.

---

## 4. `terraform validate`

↓ **PURPOSE**
Check that the configuration is syntactically valid and internally consistent.

↓ **WHAT IT DOES**
Validates syntax, required variable presence, resource references, and
attribute types. It does NOT contact AWS and cannot catch AWS-side errors.

↓ **EXPECTED OUTPUT**
```
Success! The configuration is valid.
```

↓ **COMMON ERROR**
```
Error: Unsupported argument
  An argument named "foo" is not expected here.
```
or `Error: Missing required argument`.

↓ **FIX**
Fix the typo in the HCL file, then run `terraform validate` again. Re-run
`terraform init` if a provider/required_providers block changed.

---

## 5. `terraform plan`

↓ **PURPOSE**
Show the exact changes Terraform will make, without applying them.

↓ **WHAT IT DOES**
Compares current state against the configuration, contacts AWS to read real
resource IDs, and prints an execution plan (what will be added/changed/destroyed).

↓ **EXPECTED OUTPUT**
```
Plan: 8 to add, 0 to change, 0 to destroy.
```

↓ **COMMON ERROR**
```
Error: configuring Terraform AWS Provider: no valid credential sources for
Terraform Provider found.
```

↓ **FIX**
Run `aws configure` (see `../docs/setup.md`) or set `AWS_ACCESS_KEY_ID` /
`AWS_SECRET_ACCESS_KEY` env vars. Then run `terraform plan` again.

---

## 6. `terraform apply -auto-approve`

↓ **PURPOSE**
Create or update infrastructure to match the configuration.

↓ **WHAT IT DOES**
Re-runs a plan, then performs the changes (creating real AWS resources) and
updates the state file. `-auto-approve` skips the "Enter a value: yes" prompt.

↓ **EXPECTED OUTPUT**
```
Apply complete! Resources: 8 added, 0 changed, 0 destroyed.

Outputs:
public_ip = "52.90.123.45"
```

↓ **COMMON ERROR**
`Error: creating EC2 Instance: InsufficientInstanceCapacity: ... We do not have
sufficient capacity` (see troubleshooting).

↓ **FIX**
Change `instance_type` in `terraform.tfvars` or re-run plan/apply later.

---

## 7. `terraform output`

↓ **PURPOSE**
Print the values exported by `outputs.tf`.

↓ **WHAT IT DOES**
Reads the current state file and prints each declared output.

↓ **EXPECTED OUTPUT**
```
instance_id = "i-0abcd1234efgh5678"
public_ip   = "52.90.123.45"
```

↓ **COMMON ERROR**
`The output value is not available for consumption until it is applied.`

↓ **FIX**
Run `terraform apply` first so state contains real values.

---

## 8. `terraform state list`

↓ **PURPOSE**
List every resource tracked in the state file.

↓ **WHAT IT DOES**
Prints the full addresses of all resources managed by Terraform.

↓ **EXPECTED OUTPUT**
```
aws_internet_gateway.main
aws_route_table.public
aws_security_group.web
aws_instance.web[0]
```

↓ **COMMON ERROR**
`Error: No state file was found!`

↓ **FIX**
Apply first, or check you are in the right directory / backend.

---

## 9. `terraform state show <address>`

↓ **PURPOSE**
Show the full stored attributes of a single resource.

↓ **WHAT IT DOES**
Prints the JSON/HCL representation of one resource from state, including
computed attributes like the instance ID and public IP.

↓ **EXPECTED OUTPUT**
```
# aws_instance.web[0]:
resource "aws_instance" "web" {
    id                           = "i-0abcd1234efgh5678"
    ami                          = "ami-0abcdef..."
    public_ip                    = "52.90.123.45"
    ...
}
```

↓ **COMMON ERROR**
`Error: Resource instance key not found`

↓ **FIX**
Copy the exact address from `terraform state list` (indexed resources need
`[0]`, e.g. `aws_instance.web[0]`).

---

## 10. `terraform state rm <address>`

↓ **PURPOSE**
Remove a resource from state WITHOUT destroying the real resource.

↓ **WHAT IT DOES**
Forgets a resource so Terraform will no longer manage it. The AWS resource
keeps running but is orphaned from Terraform.

↓ **EXPECTED OUTPUT**
```
Removed aws_instance.web[0]
Successfully removed 1 resource instance(s).
```

↓ **COMMON ERROR**
`Error: address aws_instance.web[0] not found in state`

↓ **FIX**
Confirm the address with `terraform state list` first.

---

## 11. `terraform destroy -auto-approve`

↓ **PURPOSE**
Delete all resources managed by this configuration.

↓ **WHAT IT DOES**
Reverses apply: terminates the instance, deletes the SG, subnet, VPC, IAM role,
etc. Use with extreme care.

↓ **EXPECTED OUTPUT**
```
Destroy complete! Resources: 8 destroyed.
```

↓ **COMMON ERROR**
`Error: DependencyViolation: ... has a dependent object` (e.g. an ENI still
attached) or the destroy hangs on a resource that cannot be deleted.

↓ **FIX**
Look at the failing resource. For a hang, terminate the instance in the AWS
console first, then re-run destroy. Never kill `terraform` mid-destroy if you
can avoid it.

---

## 12. `terraform import`

↓ **PURPOSE**
Bring an existing (manually created) AWS resource under Terraform management.

↓ **WHAT IT DOES**
Reads a live resource by its AWS ID and stores it in state, without changing it.
Format: `terraform import <address> <aws-id>`.

↓ **EXPECTED OUTPUT**
```
aws_instance.web[0]: Importing from ID "i-0abcd1234efgh5678"...
Import successful!
```

↓ **COMMON ERROR**
`Error: resource aws_instance is not yet implemented in terraform import` or
`Error: invalid instance id`.

↓ **FIX**
Check the resource supports import (`terraform providers schema`), and pass the
correct AWS resource ID (instance ID, VPC ID, SG ID, etc.).

---

## 13. `terraform console`

↓ **PURPOSE**
Open an interactive REPL to evaluate Terraform expressions.

↓ **WHAT IT DOES**
Lets you test expressions against state and variables, e.g. `var.vpc_cidr`,
`aws_vpc.main.id`, or `length(aws_instance.web)`.

↓ **EXPECTED OUTPUT**
```
> var.instance_type
"t3.micro"
> aws_vpc.main.cidr_block
"10.0.0.0/16"
> exit
```

↓ **COMMON ERROR**
`Error: Unsupported attribute`

↓ **FIX**
Type the expression exactly as it appears in the configuration, or check the
attribute exists via `terraform state show`.

---

## 14. `terraform providers`

↓ **PURPOSE**
Show the provider requirements of the configuration.

↓ **WHAT IT DOES**
Lists each provider, its source, version constraint, and where it is referenced.

↓ **EXPECTED OUTPUT**
```
Providers required by configuration:
.
└── provider[registry.terraform.io/hashicorp/aws] ~> 5.0
```

↓ **COMMON ERROR**
`Error: Unsupported provider` (wrong source/version).

↓ **FIX**
Edit `versions.tf` to the correct `required_providers` entry, then
`terraform init`.

---

## 15. `terraform workspace list`

↓ **PURPOSE**
List the available workspaces for the current configuration.

↓ **WHAT IT DOES**
Prints workspace names; `*` marks the active one. State is stored per-workspace.

↓ **EXPECTED OUTPUT**
```
  default
* dev
```

↓ **COMMON ERROR**
`Error: This command requires the `local` backend` — remote backends also work,
but the error appears if init was never run.

↓ **FIX**
Run `terraform init` first.

---

## 16. `terraform workspace new <name>`

↓ **PURPOSE**
Create and switch to a new workspace.

↓ **WHAT IT DOES**
Creates a separate state for the named workspace (e.g. `dev`, `prod`) so you can
maintain parallel environments from one configuration.

↓ **EXPECTED OUTPUT**
```
Created and switched to workspace "dev"!
```

↓ **COMMON ERROR**
`Error: Workspace "dev" already exists`

↓ **FIX**
Use `terraform workspace select dev` instead.

---

## 17. `terraform workspace select <name>`

↓ **PURPOSE**
Switch to an existing workspace.

↓ **WHAT IT DOES**
Makes the named workspace active; subsequent plan/apply/destroy run against that
workspace's state.

↓ **EXPECTED OUTPUT**
```
Switched to workspace "prod".
```

↓ **COMMON ERROR**
`Workspace "prod" doesn't exist.`

↓ **FIX**
`terraform workspace new prod` first.

---

## 18. `aws ec2 describe-instances`

↓ **PURPOSE**
Query AWS for a list of running EC2 instances.

↓ **WHAT IT DOES**
Calls the EC2 API and prints JSON with instance IDs, states, IPs, etc.

↓ **EXPECTED OUTPUT**
```
{
    "Reservations": [
        {
            "Instances": [
                {
                    "InstanceId": "i-0abcd1234efgh5678",
                    "State": { "Name": "running" },
                    ...
```

↓ **COMMON ERROR**
`An error occurred (UnauthorizedOperation) when calling the DescribeInstances
operation` or `Unable to locate credentials`.

↓ **FIX**
Run `aws configure` and ensure the IAM user has `ec2:DescribeInstances`
permission (or is an admin).

---

## 19. `ssh -i <key>.pem ubuntu@<public_ip>`

↓ **PURPOSE**
Connect to the instance over SSH.

↓ **WHAT IT DOES**
Uses your EC2 key pair to open a shell on the instance as the `ubuntu` user.

↓ **EXPECTED OUTPUT**
```
Welcome to Ubuntu 24.04 LTS ...
ubuntu@ip-10-0-1-5:~$
```

↓ **COMMON ERROR**
`Permission denied (publickey)` or `Connection timed out`.

↓ **FIX**
`Permission denied`: use the correct key and private key, run
`chmod 400 <key>.pem` on Linux/macOS. `Timed out`: your IP changed - update
`allowed_ssh_cidr` in `terraform.tfvars`, `terraform apply`, and retry. Or use
SSM instead (see troubleshooting).

---

## 20. `curl http://<public_ip>`

↓ **PURPOSE**
Test that the web stack is serving traffic.

↓ **WHAT IT DOES**
Sends an HTTP GET to nginx on the instance; nginx proxies to the Docker
container on port 3000.

↓ **EXPECTED OUTPUT**
```
Hello from the Terraform Demo App ... (HTML page)
```

↓ **COMMON ERROR**
`curl: (28) Connection timed out` or `Failed to connect to ... port 80`.

↓ **FIX**
Check the instance is running (`aws ec2 describe-instances`), the security group
allows port 80, and the user-data finished (SSH in and check
`/tmp/user-data-complete.log`).

---

## 21. `aws sts get-caller-identity`

↓ **PURPOSE**
Show which AWS account/identity your credentials belong to.

↓ **WHAT IT DOES**
Returns the account ID, ARN, and user ID of the currently configured AWS
identity.

↓ **EXPECTED OUTPUT**
```
{
    "UserId": "AIDA...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/terraform"
}
```

↓ **COMMON ERROR**
`Unable to locate credentials. You can configure credentials by running
"aws configure".`

↓ **FIX**
Run `aws configure` (see `../docs/setup.md`).

---

## 22. `aws configure`

↓ **PURPOSE**
Store AWS credentials for the AWS CLI.

↓ **WHAT IT DOES**
Prompts for access key ID, secret access key, region, and output format; saves
them to `~/.aws/credentials` and `~/.aws/config`.

↓ **EXPECTED OUTPUT**
```
AWS Access Key ID [None]: AKIA...
AWS Secret Access Key [None]: ********
Default region name [None]: us-east-1
Default output format [None]: json
```

↓ **COMMON ERROR**
`InvalidClientTokenId: The security token included in the request is invalid.`

↓ **FIX**
Re-run `aws configure` with a correct/active key pair, or create new keys in
IAM → Users → Security credentials.
