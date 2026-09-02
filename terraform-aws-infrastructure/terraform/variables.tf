variable "region" {
  description = "AWS region where all resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used to prefix and tag all resources"
  type        = string
  default     = "terraform-aws-infrastructure"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the single public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type (t2.micro / t3.micro are commonly free-tier eligible)"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair in the target region (used for SSH)"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the instance. IMPORTANT: replace with YOUR public IP, e.g. 203.0.113.5/32. No default - you must set this in terraform.tfvars."
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "allowed_ssh_cidr must be a valid CIDR block, e.g. 203.0.113.5/32. Set to your public IP via terraform.tfvars."
  }
}

variable "instance_count" {
  description = "Number of EC2 instances to launch (keep at 1 for the single-node demo)"
  type        = number
  default     = 1
}

variable "app_image" {
  description = "Docker image used to run the app container on the instance (must be pullable from Docker Hub)"
  type        = string
  default     = "nginx:latest"
}

variable "app_port" {
  description = "Host port the app container is published on (nginx reverse-proxies here)"
  type        = number
  default     = 3000
}

variable "app_internal_port" {
  description = "Port the app container listens on inside itself (nginx:latest = 80; a custom Node image = 3000)"
  type        = number
  default     = 80
}
