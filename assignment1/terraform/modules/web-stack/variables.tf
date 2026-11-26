variable "environment" {
  description = "Deployment environment name (dev, staging, or prod)."
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, or prod."
  }
}

variable "project" {
  description = "Project prefix for naming resources."
  type        = string
  default     = "acs730-a1"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,23}$", var.project))
    error_message = "project must be 3-24 lowercase letters, digits, or hyphens starting with a letter."
  }
}

variable "owner" {
  description = "Seneca username applied to resource names and tags."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the environment VPC."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnets" {
  description = "Public subnets keyed by a short stable identifier."
  type = map(object({
    cidr_block = string
    az_index   = number
  }))
}

variable "ingress_rules" {
  description = "TCP ingress rules for the web security group."
  type = list(object({
    description = string
    port        = number
    cidr_blocks = list(string)
  }))
  default = [
    { description = "HTTP inbound", port = 80, cidr_blocks = ["0.0.0.0/0"] }
  ]
}

variable "instance_type" {
  description = "EC2 instance size (constrained to stay within the $50 term budget)."
  type        = string
  default     = "t3.micro"
  validation {
    condition     = contains(["t3.micro", "t3.small"], var.instance_type)
    error_message = "instance_type must be t3.micro or t3.small."
  }
}

variable "create_artifact_bucket" {
  description = "Whether to provision an S3 artifact bucket for this environment."
  type        = bool
  default     = false
}