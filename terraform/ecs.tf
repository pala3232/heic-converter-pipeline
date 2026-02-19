resource "aws_ecs_cluster" "iosglacierbackups" {
  name = "iosglacierbackups"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecr_repository" "iosglacierbackupsconversion" {
  name = "iosglacierbackupsconversion"
  force_delete = true
}

resource "aws_ecs_task_definition" "iosglacierbackups" {
  family                   = "iosglacierbackups-conversion"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.iosglacierbackupsconversion.arn
  task_role_arn            = aws_iam_role.iosglacierbackupsconversion.arn

  container_definitions = jsonencode([
    {
      name      = "iosglacierbackups-conversion"
      image     = "${aws_ecr_repository.iosglacierbackupsconversion.repository_url}:${var.image_tag}"
      cpu       = 256
      memory    = 512
      essential = true
      environment = [
        {
          name  = "SOURCE_BUCKET"
          value = var.source_bucket
        },
        {
          name  = "DESTINATION_BUCKET"
          value = data.terraform_remote_state.source.outputs.bucket_name
        },
        {
          name  = "SQS_QUEUE_URL"
          value = aws_sqs_queue.converting-queue.url
        },
        {
          name  = "SNS_TOPIC_ARN"
          value = aws_sns_topic.user_updates.arn
        },
        {
        name  = "DYNAMODB_TABLE"
        value = aws_dynamodb_table.jobs.name
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/iosglacierbackups-conversion"
          awslogs-region        = "ap-southeast-2"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}
