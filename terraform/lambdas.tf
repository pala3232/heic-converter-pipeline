# ── Archive data sources ──────────────────────────────────────────────────────

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/../lambda-submit-sqs/lambda.py"
  output_path = "${path.module}/lambda.zip"
}

data "archive_file" "sqs_to_ecs_lambda" {
  type        = "zip"
  source_file = "${path.module}/../lambda-sqs-to-ecs/sqs_to_ecs.py"
  output_path = "${path.module}/sqs_to_ecs.zip"
}

data "archive_file" "post_jobs_lambda" {
  type        = "zip"
  source_file = "${path.module}/../lambda-post-jobs/post_jobs.py"
  output_path = "${path.module}/post_jobs.zip"
}

data "archive_file" "get_job_lambda" {
  type        = "zip"
  source_file = "${path.module}/../lambda-get-job/get_job.py"
  output_path = "${path.module}/get_job.zip"
}

data "archive_file" "list_files_lambda" {
  type        = "zip"
  source_file = "${path.module}/../lambda-list-files/list_files.py"
  output_path = "${path.module}/list_files.zip"
}

data "archive_file" "list_converted_lambda" {
  type        = "zip"
  source_file = "${path.module}/../lambda-list-converted/list_converted.py"
  output_path = "${path.module}/list_converted.zip"
}

data "archive_file" "get_presigned_lambda" {
  type        = "zip"
  source_file = "${path.module}/../lambda-get-presigned/get_presigned_url.py"
  output_path = "${path.module}/get_presigned.zip"
}

# ── Lambda functions ───────────────────────────────────────────────────────────

resource "aws_lambda_function" "s3_to_sqs" {
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  function_name    = "iosglacierbackups-s3-to-sqs"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda.handler"
  runtime          = "python3.14"

  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.converting-queue.url
    }
  }
}

resource "aws_lambda_function" "sqs_to_ecs" {
  filename         = data.archive_file.sqs_to_ecs_lambda.output_path
  source_code_hash = data.archive_file.sqs_to_ecs_lambda.output_base64sha256
  function_name    = "iosglacierbackups-sqs-to-ecs"
  role             = aws_iam_role.lambda_role.arn
  handler          = "sqs_to_ecs.handler"
  runtime          = "python3.14"

  environment {
    variables = {
      CLUSTER_ARN       = aws_ecs_cluster.iosglacierbackups.arn
      TASK_DEFINITION   = aws_ecs_task_definition.iosglacierbackups.arn
      SUBNET_ID         = aws_subnet.main.id
      SECURITY_GROUP_ID = aws_security_group.main.id
      SQS_QUEUE_URL     = aws_sqs_queue.converting-queue.url
      DYNAMODB_TABLE = aws_dynamodb_table.jobs.name
    }
  }
}

resource "aws_lambda_function" "post_jobs" {
  filename         = data.archive_file.post_jobs_lambda.output_path
  source_code_hash = data.archive_file.post_jobs_lambda.output_base64sha256
  function_name    = "iosglacierbackups-post-jobs"
  role             = aws_iam_role.lambda_role.arn
  handler          = "post_jobs.handler"
  runtime          = "python3.14"

  environment {
    variables = {
      QUEUE_URL          = aws_sqs_queue.converting-queue.url
      SOURCE_BUCKET      = var.source_bucket
      DESTINATION_BUCKET = data.terraform_remote_state.source.outputs.bucket_name
    }
  }
}

resource "aws_lambda_function" "get_job" {
  filename         = data.archive_file.get_job_lambda.output_path
  source_code_hash = data.archive_file.get_job_lambda.output_base64sha256
  function_name    = "iosglacierbackups-get-job"
  role             = aws_iam_role.lambda_role.arn
  handler          = "get_job.handler"
  runtime          = "python3.14"

  environment {
    variables = {
      CORS_ORIGIN = var.frontend_url
      DYNAMODB_TABLE = aws_dynamodb_table.jobs.name
    }
  }
}

resource "aws_lambda_function" "list_files" {
  filename         = data.archive_file.list_files_lambda.output_path
  source_code_hash = data.archive_file.list_files_lambda.output_base64sha256
  function_name    = "iosglacierbackups-list-files"
  role             = aws_iam_role.lambda_role.arn
  handler          = "list_files.handler"
  runtime          = "python3.14"

  environment {
    variables = {
      SOURCE_BUCKET = var.source_bucket
      CORS_ORIGIN = var.frontend_url
    }
  }
}

resource "aws_lambda_function" "list_converted" {
  filename         = data.archive_file.list_converted_lambda.output_path
  source_code_hash = data.archive_file.list_converted_lambda.output_base64sha256
  function_name    = "iosglacierbackups-list-converted"
  role             = aws_iam_role.lambda_role.arn
  handler          = "list_converted.handler"
  runtime          = "python3.14"

  environment {
    variables = {
      DESTINATION_BUCKET = data.terraform_remote_state.source.outputs.bucket_name
      CORS_ORIGIN        = var.frontend_url
    }
  }
}

resource "aws_lambda_function" "get_presigned" {
  filename         = data.archive_file.get_presigned_lambda.output_path
  source_code_hash = data.archive_file.get_presigned_lambda.output_base64sha256
  function_name    = "iosglacierbackups-get-presigned"
  role             = aws_iam_role.lambda_role.arn
  handler          = "get_presigned_url.handler"
  runtime          = "python3.14"

  environment {
    variables = {
      DESTINATION_BUCKET = data.terraform_remote_state.source.outputs.bucket_name
      CORS_ORIGIN = var.frontend_url
    }
  }
}

# ── Lambda permissions ─────────────────────────────────────────────────────────

resource "aws_lambda_permission" "allow_eventbridge_to_invoke_sqs_to_ecs" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sqs_to_ecs.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.alarm_sqs_messages.arn
}

resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_to_sqs.function_name
  principal     = "s3.amazonaws.com"
  source_arn = "arn:aws:s3:::${var.source_bucket}"

}

resource "aws_lambda_permission" "post_jobs_apigw" {
  statement_id  = "AllowAPIGatewayInvokePostJobs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_jobs.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.jobs_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "get_job_apigw" {
  statement_id  = "AllowAPIGatewayInvokeGetJob"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_job.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.jobs_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "list_files_apigw" {
  statement_id  = "AllowAPIGatewayInvokeListFiles"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_files.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.jobs_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "list_converted_apigw" {
  statement_id  = "AllowAPIGatewayInvokeListConverted"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_converted.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.jobs_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "get_presigned_apigw" {
  statement_id  = "AllowAPIGatewayInvokeGetPresigned"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_presigned.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.jobs_api.execution_arn}/*/*"
}

# ── S3 bucket notification ─────────────────────────────────────────────────────

resource "aws_s3_bucket_notification" "source_bucket_notification" {
  bucket = var.source_bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_to_sqs.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".heic"
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}
