resource "aws_sqs_queue" "converting-queue" {
  name = "converting-queue"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.converting-dlq.arn
    maxReceiveCount     = 2
  })
}

resource "aws_sqs_queue" "converting-dlq" {
  name = "converting-dlq"
}

resource "aws_sqs_queue_redrive_allow_policy" "terraform_queue_redrive_allow_policy" {
  queue_url = aws_sqs_queue.converting-dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.converting-queue.arn]
  })
}
