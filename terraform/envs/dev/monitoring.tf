# CloudWatch Alarm (StatusCheckFailed) → SNS Topic → 이메일 + Lambda(Discord)

# -----------------------------------------------------------------------------
# SNS Topic — 알림 라우팅 허브
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "monitoring_alert" {
  name = "qfeed-dev-sns-monitoring-alert"

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-sns-monitoring-alert"
  })
}

resource "aws_sns_topic_subscription" "monitoring_alert_email" {
  topic_arn = aws_sns_topic.monitoring_alert.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_subscription" "monitoring_alert_discord" {
  topic_arn = aws_sns_topic.monitoring_alert.arn
  protocol  = "lambda"
  endpoint  = "arn:aws:lambda:ap-northeast-2:092399857215:function:qfeed-prod-lambda-discord-webhook"
}

resource "aws_lambda_permission" "sns_monitoring_alert" {
  statement_id  = "AllowSNSMonitoringAlert"
  action        = "lambda:InvokeFunction"
  function_name = "qfeed-prod-lambda-discord-webhook"
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.monitoring_alert.arn
}

# -----------------------------------------------------------------------------
# CloudWatch Alarm — 모니터링 EC2 StatusCheckFailed
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "monitoring_status_check" {
  alarm_name          = "qfeed-dev-alarm-monitoring-status-check"
  alarm_description   = "Monitoring EC2 StatusCheckFailed - Deadman's Switch"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "breaching" # 데이터 없음 = EC2 죽은 것으로 간주

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.monitoring.name
  }

  alarm_actions = [aws_sns_topic.monitoring_alert.arn]
  ok_actions    = [aws_sns_topic.monitoring_alert.arn]

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-alarm-monitoring-status-check"
  })
}
