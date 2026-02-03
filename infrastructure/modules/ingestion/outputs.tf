output "lambda_function_name" {
  value = aws_lambda_function.theoddsapi.function_name
}

output "event_rule_name" {
  value = aws_cloudwatch_event_rule.schedule.name
}