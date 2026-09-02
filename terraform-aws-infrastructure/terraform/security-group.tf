# Security group for the EC2 instance.
# Rule of thumb: allow ONLY the traffic the instance actually needs.
resource "aws_security_group" "web" {
  name        = "${var.project_name}-${var.environment}-web-sg"
  description = "Allow SSH from your IP, HTTP/HTTPS from anywhere, all outbound"
  vpc_id      = aws_vpc.main.id

  # SSH only from your own IP (NOT 0.0.0.0/0) - least privilege
  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # HTTP from the public internet (web traffic reaches nginx)
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS from the public internet (for a future TLS endpoint)
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # App port is intentionally NOT exposed to the internet.
  # Only nginx (localhost:3000) talks to the app container.

  # All outbound traffic allowed
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-web-sg"
  }
}
