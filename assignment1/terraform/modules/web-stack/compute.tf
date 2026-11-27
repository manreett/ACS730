data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }
}

locals {
  first_subnet_key = sort(keys(local.public_subnets))[0]
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[local.first_subnet_key].id
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
    dnf -y install nginx
    echo "<h1>ACS730 Assignment 1 - ${var.environment} (${local.name_prefix})</h1>" > /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOT

  depends_on = [aws_route_table_association.public]

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-web" })
}

resource "aws_s3_bucket" "artifacts" {
  count         = var.create_artifact_bucket ? 1 : 0
  bucket        = "${local.name_prefix}-artifacts"
  force_destroy = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-artifacts" })
}

data "aws_ssm_parameter" "db_password" {
  name            = "/acs730/assignment1/prod/db-password"
  with_decryption = true
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${local.name_prefix}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Triggers when ${local.name_prefix} EC2 CPU utilization exceeds 80% for 2 minutes."
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.web.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-high-cpu"
  })
}