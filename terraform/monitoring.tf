resource "aws_cloudwatch_log_group" "iosglacierbackups" {
  name = "/ecs/iosglacierbackups-conversion"
}

resource "aws_cloudwatch_metric_alarm" "messages_in_sqs" {
  alarm_name          = "messages_in_sqs"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  period              = 60
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  statistic           = "Average"
  threshold           = "10"
  alarm_description   = "ApproximateNumberOfMessagesVisible"
  actions_enabled     = "true"
  dimensions = {
    QueueName = "converting-queue"
  }
}

resource "aws_cloudwatch_event_rule" "alarm_sqs_messages" {
  name        = "alarm_sqs_messages"
  description = "Capture CloudWatch Alarm state changes"

  event_pattern = jsonencode({
    "source" : ["aws.cloudwatch"],
    "detail-type" : ["CloudWatch Alarm State Change"],
    "resources" : [aws_cloudwatch_metric_alarm.messages_in_sqs.arn],
    "detail" : {
      "state" : {
        "value" : ["ALARM"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "sqs_to_ecs_lambda" {
  rule = aws_cloudwatch_event_rule.alarm_sqs_messages.name
  arn  = aws_lambda_function.sqs_to_ecs.arn
}

resource "aws_sns_topic" "user_updates" {
  name = "notifications-email"
}

resource "aws_sns_topic_subscription" "notifications-email" {
  topic_arn = aws_sns_topic.user_updates.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_dynamodb_table" "jobs" {
  name         = "iosglacierbackups-jobs"
  hash_key     = "job_id"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "job_id"
    type = "S"
  }
}
