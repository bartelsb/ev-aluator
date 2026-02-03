resource "aws_iam_role" "lambda_role" {
  name = "ev-aluator-ingestion-role-${terraform.workspace}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name = "ev-aluator-ingestion-policy-${terraform.workspace}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          var.snowflake_secret_arn,
          var.odds_api_secret_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_layer_version" "snowflake" {
  description         = "Lambda layer for snowflake connector"
  filename            = "${path.module}/lambdas/layers/snowflake.zip"
  layer_name          = "snowflake-connector-python"
  compatible_runtimes = ["python3.13"]
  source_code_hash    = filebase64sha256("${path.module}/lambdas/layers/snowflake.zip")
}

data "archive_file" "theoddsapi_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/theoddsapi"
  output_path = "${path.module}/theoddsapi_lambda.zip"
}

resource "aws_lambda_function" "theoddsapi" {
  function_name = "ev-aluator-ingest-theoddsapi-${terraform.workspace}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.13"

  filename         = data.archive_file.theoddsapi_lambda_zip.output_path
  source_code_hash = data.archive_file.theoddsapi_lambda_zip.output_base64sha256

  layers = [aws_lambda_layer_version.snowflake.arn]

  timeout = 60
  memory_size = 512

  environment {
    variables = {
      SNOWFLAKE_SECRET_ARN = var.snowflake_secret_arn
      ODDS_API_SECRET_ARN  = var.odds_api_secret_arn
      WORKSPACE            = terraform.workspace
    }
  }
}

resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "ev-aluator-ingest-theoddsapi-schedule-${terraform.workspace}"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = "lambda"
  arn       = aws_lambda_function.theoddsapi.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.theoddsapi.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}


