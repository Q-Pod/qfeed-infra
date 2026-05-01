output "alb_dns_name" {
  description = "ALB DNS name (CloudFront 오리진으로 사용)"
  value       = aws_lb.backend.dns_name
}

output "rds_endpoint" {
  description = "RDS 엔드포인트 (host:port)"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_address" {
  description = "RDS 호스트 (포트 제외)"
  value       = aws_db_instance.postgres.address
}

output "asg_name" {
  description = "ASG 이름"
  value       = aws_autoscaling_group.backend.name
}

output "ssm_connect_command" {
  description = "SSM 접속 명령어 (instance ID는 ASG에서 조회)"
  value       = "aws ssm start-session --target <INSTANCE_ID>"
}

output "find_instance_command" {
  description = "ASG 인스턴스 ID 조회"
  value       = "aws autoscaling describe-auto-scaling-instances --query 'AutoScalingInstances[?AutoScalingGroupName==`${aws_autoscaling_group.backend.name}`].InstanceId' --output text"
}

# -----------------------------------------------------------------------------
# AI Server
# -----------------------------------------------------------------------------

output "ai_asg_name" {
  description = "AI Server ASG 이름"
  value       = aws_autoscaling_group.ai.name
}

output "ai_sg_id" {
  description = "AI Server Security Group ID"
  value       = aws_security_group.ai.id
}

output "find_ai_instance_command" {
  description = "AI Server ASG 인스턴스 ID 조회"
  value       = "aws autoscaling describe-auto-scaling-instances --query 'AutoScalingInstances[?AutoScalingGroupName==`${aws_autoscaling_group.ai.name}`].InstanceId' --output text"
}

# -----------------------------------------------------------------------------
# Monitoring Server
# -----------------------------------------------------------------------------

output "monitoring_asg_name" {
  description = "Monitoring Server ASG 이름"
  value       = aws_autoscaling_group.monitoring.name
}

output "monitoring_sg_id" {
  description = "Monitoring Server Security Group ID"
  value       = aws_security_group.monitoring.id
}

output "find_monitoring_instance_command" {
  description = "Monitoring Server ASG 인스턴스 ID 조회"
  value       = "aws autoscaling describe-auto-scaling-instances --query 'AutoScalingInstances[?AutoScalingGroupName==`${aws_autoscaling_group.monitoring.name}`].InstanceId' --output text"
}

output "grafana_port_forwarding_command" {
  description = "Grafana 접근 (SSM Port Forwarding)"
  value       = "aws ssm start-session --target <INSTANCE_ID> --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"3000\"],\"localPortNumber\":[\"3000\"]}'"
}

output "sns_topic_arn" {
  description = "모니터링 알림 SNS Topic ARN"
  value       = aws_sns_topic.monitoring_alert.arn
}
