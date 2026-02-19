locals {
  cors_origin = var.frontend_url
}

# rest api

resource "aws_api_gateway_rest_api" "jobs_api" {
  name = "iosglacierbackup-jobs-api"
}

resource "aws_api_gateway_authorizer" "cognito" {
  name            = "cognito-authorizer"
  rest_api_id     = aws_api_gateway_rest_api.jobs_api.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [aws_cognito_user_pool.pool.arn]
  identity_source = "method.request.header.Authorization"
}

resource "aws_api_gateway_deployment" "jobs_api" {
  rest_api_id = aws_api_gateway_rest_api.jobs_api.id

  triggers = {
    redeploy = sha1(jsonencode([
      aws_api_gateway_integration.post_jobs,
      aws_api_gateway_integration.get_job,
      aws_api_gateway_integration.get_files,
      aws_api_gateway_integration.get_converted,
      aws_api_gateway_integration.get_presigned,
      aws_api_gateway_integration_response.job_id_options_200,
      aws_api_gateway_integration_response.files_options_200,
      aws_api_gateway_integration_response.jobs_options_200,
      aws_api_gateway_integration_response.converted_options_200,
      aws_api_gateway_integration_response.presigned_options_200,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.post_jobs,
    aws_api_gateway_integration.get_job,
    aws_api_gateway_integration.get_files,
    aws_api_gateway_method.files_options,
    aws_api_gateway_integration.files_options_mock,
    aws_api_gateway_method_response.files_options_200,
    aws_api_gateway_integration_response.files_options_200,
    aws_api_gateway_method.job_id_options,
    aws_api_gateway_integration.job_id_options_mock,
    aws_api_gateway_method_response.job_id_options_200,
    aws_api_gateway_integration_response.job_id_options_200,
    aws_api_gateway_integration.get_converted,
    aws_api_gateway_integration.get_presigned,
    aws_api_gateway_integration_response.converted_options_200,
    aws_api_gateway_integration_response.presigned_options_200,
  ]
}

resource "aws_api_gateway_stage" "jobs-stage" {
  deployment_id = aws_api_gateway_deployment.jobs_api.id
  rest_api_id   = aws_api_gateway_rest_api.jobs_api.id
  stage_name    = "prod"

  lifecycle {
    replace_triggered_by = [aws_api_gateway_deployment.jobs_api]
  }
}

# /jobs

resource "aws_api_gateway_resource" "jobs" {
  rest_api_id = aws_api_gateway_rest_api.jobs_api.id
  parent_id   = aws_api_gateway_rest_api.jobs_api.root_resource_id
  path_part   = "jobs"
}

resource "aws_api_gateway_method" "post_jobs" {
  rest_api_id   = aws_api_gateway_rest_api.jobs_api.id
  resource_id   = aws_api_gateway_resource.jobs.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "post_jobs" {
  rest_api_id             = aws_api_gateway_rest_api.jobs_api.id
  resource_id             = aws_api_gateway_resource.jobs.id
  http_method             = aws_api_gateway_method.post_jobs.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.post_jobs.invoke_arn
}

resource "aws_api_gateway_method" "jobs_options" {
  rest_api_id   = aws_api_gateway_rest_api.jobs_api.id
  resource_id   = aws_api_gateway_resource.jobs.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "jobs_options_mock" {
  rest_api_id       = aws_api_gateway_rest_api.jobs_api.id
  resource_id       = aws_api_gateway_resource.jobs.id
  http_method       = aws_api_gateway_method.jobs_options.http_method
  type              = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}

resource "aws_api_gateway_method_response" "jobs_options_200" {
  rest_api_id = aws_api_gateway_rest_api.jobs_api.id
  resource_id = aws_api_gateway_resource.jobs.id
  http_method = aws_api_gateway_method.jobs_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "jobs_options_200" {
  rest_api_id = aws_api_gateway_rest_api.jobs_api.id
  resource_id = aws_api_gateway_resource.jobs.id
  http_method = aws_api_gateway_method.jobs_options.http_method
  status_code = aws_api_gateway_method_response.jobs_options_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${local.cors_origin}'"
  }
}

# /jobs/{id} 

resource "aws_api_gateway_resource" "job_id" {
  rest_api_id = aws_api_gateway_rest_api.jobs_api.id
  parent_id   = aws_api_gateway_resource.jobs.id
  path_part   = "{id}"
}

resource "aws_api_gateway_method" "get_job" {
  rest_api_id   = aws_api_gateway_rest_api.jobs_api.id
  resource_id   = aws_api_gateway_resource.job_id.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "get_job" {
  rest_api_id             = aws_api_gateway_rest_api.jobs_api.id
  resource_id             = aws_api_gateway_resource.job_id.id
  http_method             = aws_api_gateway_method.get_job.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_job.invoke_arn
}

resource "aws_api_gateway_method" "job_id_options" {
  rest_api_id   = aws_api_gateway_rest_api.jobs_api.id
  resource_id   = aws_api_gateway_resource.job_id.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "job_id_options_mock" {
  rest_api_id       = aws_api_gateway_rest_api.jobs_api.id
  resource_id       = aws_api_gateway_resource.job_id.id
  http_method       = aws_api_gateway_method.job_id_options.http_method
  type              = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}

resource "aws_api_gateway_method_response" "job_id_options_200" {
  rest_api_id = aws_api_gateway_rest_api.jobs_api.id
  resource_id = aws_api_gateway_resource.job_id.id
  http_method = aws_api_gateway_method.job_id_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "job_id_options_200" {
  rest_api_id = aws_api_gateway_rest_api.jobs_api.id
  resource_id = aws_api_gateway_resource.job_id.id
  http_method = aws_api_gateway_method.job_id_options.http_method
  status_code = aws_api_gateway_method_response.job_id_options_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${local.cors_origin}'"
  }
}

# /files

resource "aws_api_gateway_resource" "files" {
  rest_api_id = aws_api_gateway_rest_api.jobs_api.id
  parent_id   = aws_api_gateway_rest_api.jobs_api.root_resource_id
  path_part   = "files"
}

resource "aws_api_gateway_method" "get_files" {
  rest_api_id   = aws_api_gateway_rest_api.jobs_api.id
  resource_id   = aws_api_gateway_resource.files.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "get_files" {
  rest_api_id             = aws_api_gateway_rest_api.jobs_api.id
  resource_id             = aws_api_gateway_resource.files.id
  http_method             = aws_api_gateway_method.get_files.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.list_files.invoke_arn
}

resource "aws_api_gateway_method" "files_options" {
  rest_api_id   = aws_api_gateway_rest_api.jobs_api.id
  resource_id   = aws_api_gateway_resource.files.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "files_options_mock" {
  rest_api_id       = aws_api_gateway_rest_api.jobs_api.id
  resource_id       = aws_api_gateway_resource.files.id
  http_method       = aws_api_gateway_method.files_options.http_method
  type              = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}

resource "aws_api_gateway_method_response" "files_options_200" {
  rest_api_id = aws_api_gateway_rest_api.jobs_api.id
  resource_id = aws_api_gateway_resource.files.id
  http_method = aws_api_gateway_method.files_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "files_options_200" {
  rest_api_id = aws_api_gateway_rest_api.jobs_api.id
  resource_id = aws_api_gateway_resource.files.id
  http_method = aws_api_gateway_method.files_options.http_method
  status_code = aws_api_gateway_method_response.files_options_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${local.cors_origin}'"
  }
}

# /converted

resource "aws_api_gateway_resource" "converted" {
  rest_api_id = aws_api_gateway_rest_api.jobs_api.id
  parent_id   = aws_api_gateway_rest_api.jobs_api.root_resource_id
  path_part   = "converted"
}

resource "aws_api_gateway_method" "get_converted" {
  rest_api_id   = aws_api_gateway_rest_api.jobs_api.id
  resource_id   = aws_api_gateway_resource.converted.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "get_converted" {
  rest_api_id             = aws_api_gateway_rest_api.jobs_api.id
  resource_id             = aws_api_gateway_resource.converted.id
  http_method             = aws_api_gateway_method.get_converted.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.list_converted.invoke_arn
}

resource "aws_api_gateway_method" "converted_options" {
  rest_api_id   = aws_api_gateway_rest_api.jobs_api.id
  resource_id   = aws_api_gateway_resource.converted.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "converted_options_mock" {
  rest_api_id       = aws_api_gateway_rest_api.jobs_api.id
  resource_id       = aws_api_gateway_resource.converted.id
  http_method       = aws_api_gateway_method.converted_options.http_method
  type              = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}

resource "aws_api_gateway_method_response" "converted_options_200" {
  rest_api_id = aws_api_gateway_rest_api.jobs_api.id
  resource_id = aws_api_gateway_resource.converted.id
  http_method = aws_api_gateway_method.converted_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "converted_options_200" {
  rest_api_id = aws_api_gateway_rest_api.jobs_api.id
  resource_id = aws_api_gateway_resource.converted.id
  http_method = aws_api_gateway_method.converted_options.http_method
  status_code = aws_api_gateway_method_response.converted_options_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${local.cors_origin}'"
  }
}

# /presigned 

resource "aws_api_gateway_resource" "presigned" {
  rest_api_id = aws_api_gateway_rest_api.jobs_api.id
  parent_id   = aws_api_gateway_rest_api.jobs_api.root_resource_id
  path_part   = "presigned"
}

resource "aws_api_gateway_method" "get_presigned" {
  rest_api_id   = aws_api_gateway_rest_api.jobs_api.id
  resource_id   = aws_api_gateway_resource.presigned.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "get_presigned" {
  rest_api_id             = aws_api_gateway_rest_api.jobs_api.id
  resource_id             = aws_api_gateway_resource.presigned.id
  http_method             = aws_api_gateway_method.get_presigned.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_presigned.invoke_arn
}

resource "aws_api_gateway_method" "presigned_options" {
  rest_api_id   = aws_api_gateway_rest_api.jobs_api.id
  resource_id   = aws_api_gateway_resource.presigned.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "presigned_options_mock" {
  rest_api_id       = aws_api_gateway_rest_api.jobs_api.id
  resource_id       = aws_api_gateway_resource.presigned.id
  http_method       = aws_api_gateway_method.presigned_options.http_method
  type              = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}

resource "aws_api_gateway_method_response" "presigned_options_200" {
  rest_api_id = aws_api_gateway_rest_api.jobs_api.id
  resource_id = aws_api_gateway_resource.presigned.id
  http_method = aws_api_gateway_method.presigned_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "presigned_options_200" {
  rest_api_id = aws_api_gateway_rest_api.jobs_api.id
  resource_id = aws_api_gateway_resource.presigned.id
  http_method = aws_api_gateway_method.presigned_options.http_method
  status_code = aws_api_gateway_method_response.presigned_options_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${local.cors_origin}'"
  }
}
