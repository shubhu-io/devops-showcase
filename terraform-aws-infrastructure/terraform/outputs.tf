# Outputs for the created resources. Sensitive values are masked by default.
# Scalars point at the first instance (aws_instance.web[0]) so they can be used
# directly with `terraform output -raw public_ip` (used by the Makefile).
output "instance_id" {
  description = "ID of the launched EC2 instance"
  value       = aws_instance.web[0].id
}

output "public_ip" {
  description = "Public IPv4 address of the instance - visit http://<ip> in a browser"
  value       = aws_instance.web[0].public_ip
}

output "public_dns" {
  description = "Public DNS name of the instance"
  value       = aws_instance.web[0].public_dns
}

output "ssh_command" {
  description = "SSH command to connect to the instance (uses the configured key pair)"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.web[0].public_dns}"
}
