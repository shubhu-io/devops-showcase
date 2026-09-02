# ---------------------------------------------------------------------------
# Data sources: latest official Ubuntu 24.04 LTS AMI and AZs for the region
# ---------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ---------------------------------------------------------------------------
# EC2 instance(s)
# ---------------------------------------------------------------------------
resource "aws_instance" "web" {
  count = var.instance_count

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
    tags = {
      Name = "${var.project_name}-${var.environment}-root-${count.index + 1}"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # Bootstrap script rendered with template vars, then base64-encoded
  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    app_image         = var.app_image
    app_port          = var.app_port
    app_internal_port = var.app_internal_port
  }))

  # Re-run bootstrap on every plan/apply change (e.g. after editing user-data.sh)
  user_data_replace_on_change = true

  tags = {
    Name = "${var.project_name}-${var.environment}-web-${count.index + 1}"
  }
}

# ---------------------------------------------------------------------------
# Optional: attach a static Elastic IP. Commented out because public IPs from
# the default pool are free, while EIPs can cost money when unattached.
# Uncomment to pin the IP across instance replacement.
# ---------------------------------------------------------------------------
# resource "aws_eip" "web" {
#   count    = var.instance_count
#   instance = aws_instance.web[count.index].id
#
#   tags = {
#     Name = "${var.project_name}-${var.environment}-eip-${count.index + 1}"
#   }
# }
