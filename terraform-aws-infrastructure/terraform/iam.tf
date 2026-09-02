# IAM role the EC2 instance assumes. The instance gets short-lived
# temporary credentials from STS - no long-lived access keys on the box.

# Trust policy: EC2 is allowed to assume this role
resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-role"
  }
}

# AWS managed policy: Systems Manager. Lets you SSH/connect WITHOUT a key
# (SSM Session Manager) and is the recommended alternative to opening port 22.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Minimal inline policy: read a single S3 bucket (placeholder).
# Least privilege: the instance can do EXACTLY this and nothing else.
resource "aws_iam_role_policy" "s3_read" {
  name = "s3-app-bucket-read"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "arn:aws:s3:::your-app-bucket-placeholder/*"
      }
    ]
  })
}

# Instance profile wraps the role so EC2 can assume it
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name
}
