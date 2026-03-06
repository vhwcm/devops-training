provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3           = "http://localhost:4566"
    lambda       = "http://localhost:4566"
    iam          = "http://localhost:4566"
    dynamodb     = "http://localhost:4566"
    sts          = "http://localhost:4566"
    ec2          = "http://localhost:4566"
    autoscaling  = "http://localhost:4566"
    elb          = "http://localhost:4566"
    elbv2        = "http://localhost:4566"
    apigateway   = "http://localhost:4566"
    codedeploy   = "http://localhost:4566"
    codepipeline = "http://localhost:4566"
  }
}

resource "aws_s3_bucket" "entrada" {
  bucket = "bucket-entrada-python"
}

# objeto armazeno dentro do bucket acima
resource "aws_iam_role" "role" {
  name = "role_lambda_python"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_lambda_function" "func" {
  filename      = "function.zip"
  function_name = "logger_s3_to_dynamo"
  role          = aws_iam_role.role.arn
  handler       = "index.handler"
  runtime       = "python3.11"
}

resource "aws_lambda_permission" "allow_s3" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.func.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.entrada.arn
}

resource "aws_s3_bucket_notification" "notif" {
  bucket = aws_s3_bucket.entrada.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.func.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.allow_s3]
}

resource "aws_dynamodb_table" "logs" {
  name         = "LogsArquivos"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ArquivoID"

  attribute {
    name = "ArquivoID"
    type = "S"
  }
}
