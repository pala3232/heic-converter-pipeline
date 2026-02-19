resource "aws_cognito_user_pool" "pool" {
  name = "user-pool-converting"
}

resource "aws_cognito_user_pool_client" "client" {
  name         = "user-pool-converting-client"
  user_pool_id = aws_cognito_user_pool.pool.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "iosglacierbackups"
  user_pool_id = aws_cognito_user_pool.pool.id
}
