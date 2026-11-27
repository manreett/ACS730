output "vpc_id" {
  description = "ID of the environment VPC."
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "Map of public subnet IDs keyed by subnet key."
  value       = { for k, s in aws_subnet.public : k => s.id }
}

output "web_instance_id" {
  description = "EC2 instance ID (consumed by CloudWatch alarm in Task 7)."
  value       = aws_instance.web.id
}

output "web_public_ip" {
  description = "Public IPv4 address of the web instance."
  value       = aws_instance.web.public_ip
}

output "web_url" {
  description = "HTTP endpoint URL for the web server."
  value       = "http://${aws_instance.web.public_ip}/"
}

output "artifact_bucket" {
  description = "Name of the optional artifact bucket, or null."
  value       = one(aws_s3_bucket.artifacts[*].bucket)
}

output "db_password_parameter_arn" {
  description = "ARN of the SSM parameter read via data source."
  value       = data.aws_ssm_parameter.db_password.arn
}

output "cloudwatch_alarm_name" {
  description = "Name of the CloudWatch CPU utilization alarm."
  value       = aws_cloudwatch_metric_alarm.high_cpu.alarm_name
}