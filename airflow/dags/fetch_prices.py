from datetime import datetime, timedelta

import psycopg2
import requests
from airflow.decorators import dag, task
from airflow.operators.bash import BashOperator
from psycopg2.extras import Json

DB = dict(
    host="warehouse-db",
    port=5432,
    dbname="finance_dwh",
    user="warehouse",
    password="warehouse",
)

DBT_FLAGS = (
    "--project-dir /opt/airflow/finance_dbt "
    "--target-path /tmp/dbt_target "
    "--log-path /tmp/dbt_logs"
)


def save(source, symbol, price, payload):
    conn = psycopg2.connect(**DB)
    try:
        with conn, conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO raw.api_prices (source, symbol, price, price_date, payload)
                VALUES (%s, %s, %s, CURRENT_DATE, %s)
                ON CONFLICT (source, symbol, price_date)
                DO UPDATE SET
                    price = EXCLUDED.price,
                    payload = EXCLUDED.payload,
                    ingested_at = NOW()
                """,
                (source, symbol, price, Json(payload)),
            )
    finally:
        conn.close()


@dag(
    dag_id="fetch_prices",
    schedule="@daily",
    start_date=datetime(2026, 10, 1),
    catchup=False,
    default_args={"retries": 2, "retry_delay": timedelta(minutes=2)},
    tags=["finance"],
)
def fetch_prices():
    @task
    def fetch_fx():
        r = requests.get(
            "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json",
            timeout=15,
        )
        r.raise_for_status()
        data = r.json()
        egp = data["usd"]["egp"]
        save("currency_api", "USD/EGP", egp, {"date": data["date"], "egp": egp})

    @task
    def fetch_crypto():
        r = requests.get(
            "https://api.coingecko.com/api/v3/simple/price",
            params={"ids": "bitcoin", "vs_currencies": "usd"},
            timeout=10,
        )
        r.raise_for_status()
        data = r.json()
        save("coingecko", "BTC/USD", data["bitcoin"]["usd"], data)

    dbt_run = BashOperator(
        task_id="dbt_run",
        bash_command=f"dbt run {DBT_FLAGS}",
    )

    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=f"dbt test {DBT_FLAGS}",
    )

    fx = fetch_fx()
    crypto = fetch_crypto()
    [fx, crypto] >> dbt_run >> dbt_test


fetch_prices()