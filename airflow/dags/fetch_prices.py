from datetime import datetime, timedelta

import psycopg2
import requests
from airflow.decorators import dag, task
from psycopg2.extras import Json

DB = dict(
    host="warehouse-db",
    port=5432,
    dbname="finance_dwh",
    user="warehouse",
    password="warehouse",
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
        r = requests.get("https://open.er-api.com/v6/latest/USD", timeout=10)
        r.raise_for_status()
        data = r.json()
        save("open_er_api", "USD/EGP", data["rates"]["EGP"], data)

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

    fetch_fx()
    fetch_crypto()


fetch_prices()