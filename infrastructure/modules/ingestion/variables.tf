variable "schedule_expression" {
  type        = string
  description = "EventBridge schedule expression"
}

variable "snowflake_secret_arn" {
  type        = string
  description = "ARN of Snowflake credentials secret"
}

variable "odds_api_secret_arn" {
  type        = string
  description = "ARN of Odds API key secret"
}