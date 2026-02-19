variable "image_tag" {
  default = "latest"
}

output "api_gateway_url" {
  value = aws_api_gateway_stage.jobs-stage.invoke_url
}

variable "source_bucket" {
  description = "Name of the S3 bucket containing source HEIC files"
  type        = string
}

variable "notification_email" {
  default = "example@gmail.com"
}

variable "frontend_url" {
  default = "https://s3-static-site-yoursite.s3.ap-southeast-2.amazonaws.com"
}