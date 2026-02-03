module "ingestion" {
  source = "../modules/ingestion"

  schedule_expression   = "rate(30 minutes)"

  snowflake_secret_arn  = "arn:aws:secretsmanager:us-east-2:198764381282:secret:snowflake_credentials-33atC7"
  odds_api_secret_arn   = "arn:aws:secretsmanager:us-east-2:198764381282:secret:theoddsapi_apikey-Po9YkC"
}