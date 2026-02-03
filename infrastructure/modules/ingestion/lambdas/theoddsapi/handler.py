import json
import logging
import boto3
import urllib.request
import urllib.parse
import snowflake.connector
from datetime import datetime, timezone
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

secrets_client = boto3.client("secretsmanager")
sf_ctx = None

def get_secret_json(secret_arn: str) -> dict:
    response = secrets_client.get_secret_value(SecretId=secret_arn)
    return json.loads(response["SecretString"])

def get_snowflake_conn(creds):
    """Maintains a persistent Snowflake connection across warm starts."""
    global sf_ctx

    if sf_ctx is None or sf_ctx.is_closed():
        logger.info("Establishing new Snowflake connection...")
        sf_ctx = snowflake.connector.connect(
            account   = creds["account"],
            user      = creds["user"],
            password  = creds["password"],
            warehouse = creds["warehouse"],
            database  = creds["database"],
            schema    = creds["schema"],
        )
    return sf_ctx

def fetch_odds(api_key: str):
    params = {
        "apiKey": api_key,
        "regions": "us",
        "markets": "h2h",
        "oddsFormat": "american"
    }

    query = urllib.parse.urlencode(params)
    url = f"https://api.the-odds-api.com/v4/sports/basketball_nba/odds?{query}"

    with urllib.request.urlopen(url, timeout=10) as response:
        body = json.loads(response.read())
        headers = dict(response.headers)

    return body, headers

def write_to_snowflake(events: list, conn):
    cs = conn.cursor()

    insert_sql = """
        INSERT INTO RAW_EVENTS (event_id, source, endpoint, sport, payload, ingested_at)
        SELECT $1, $2, $3, $4, PARSE_JSON($5), CURRENT_TIMESTAMP()
        FROM VALUES (%s, %s, %s, %s, %s)
    """

    rows = [
        (
            event["id"],
            "theoddsapi",
            "/v4/sports/basketball_nba/odds",
            event["sport_key"],
            json.dumps(event)
        )
        for event in events
    ]

    cs.executemany(insert_sql, rows)

    cs.close()

    return len(rows)

def lambda_handler(event, context):
    logger.info("Lambda invoked")

    odds_api_secret_arn = os.getenv("ODDS_API_SECRET_ARN")
    snowflake_secret_arn = os.getenv("SNOWFLAKE_SECRET_ARN")

    api_key = secrets_client.get_secret_value(
        SecretId=odds_api_secret_arn
    )["SecretString"]

    sf_creds = get_secret_json(snowflake_secret_arn)
    conn = get_snowflake_conn(sf_creds)

    events, headers = fetch_odds(api_key)
    inserted = write_to_snowflake(events, conn)

    logger.info({
        "events_fetched": len(events),
        "rows_inserted": inserted,
        "remaining_requests": headers.get("x-requests-remaining"),
    })

    return {
        "statusCode": 200,
        "body": json.dumps({
            "events_fetched": len(events),
            "rows_inserted": inserted
        })
    }
