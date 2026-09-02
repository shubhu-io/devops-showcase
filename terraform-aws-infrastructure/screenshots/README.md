# Screenshots

This folder holds real screenshots captured while running the project.

**No screenshots are committed in this repo.** Do not fabricate images - capture
them from your own run so they reflect reality.

## What to capture (in order)

1. **terraform init** - provider plugin download finishing with
   *"Terraform has been successfully initialized!"*.
2. **terraform validate** - *"Success! The configuration is valid."*
3. **terraform plan** - the resource table showing ~6 to add (`aws_vpc`,
   `aws_subnet`, `aws_security_group`, `aws_iam_role`, `aws_instance`, ...) and
   `Plan: N to add`.
4. **terraform apply** - resource creation progress and the final outputs block
   (`instance_id`, `public_ip`, `public_dns`, `ssh_command`).
5. **AWS Console → EC2 → Instances** - the running `terraform-aws-docker-dev-web-1`
   instance with its public IP and status checks passed.
6. **Browser** - `http://<public_ip>/` showing the app page, then
   `http://<public_ip>/health` showing the JSON.
7. **curl output** - `curl http://$(terraform output -raw public_ip)` returning HTML.
8. **terraform destroy** - resources being destroyed and
   *"Destroy complete! Resources: N destroyed."*

## Naming convention

`01-init.png`, `02-validate.png`, `03-plan.png`, `04-apply.png`,
`05-ec2-console.png`, `06-browser-app.png`, `07-browser-health.png`,
`08-curl.png`, `09-destroy.png`

## Tips

- Blur or redact anything sensitive (account IDs, IPs, keys) before committing.
- Keep them small (< 300 KB each) to keep the repo light.
