from datetime import date, datetime, timedelta, timezone

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

DAYS = 90

UPSERT = """
    INSERT INTO raw.api_prices (source, symbol, price, price_date, payload)
    VALUES (%s, %s, %s, %s, %s)
    ON CONFLICT (source, symbol, price_date)
    DO UPDATE SET
        price = EXCLUDED.price,
        payload = EXCLUDED.payload,
        ingested_at = NOW()
"""


def save_many(rows):
    conn = psycopg2.connect(**DB)
    try:
        with conn, conn.cursor() as cur:
            for row in rows:
                cur.execute(UPSERT, row)
    finally:
        conn.close()


@dag(
    dag_id="backfill_prices",
    schedule=None,
    start_date=datetime(2026, 10, 1),
    catchup=False,
    tags=["finance", "backfill"],
)
def backfill_prices():
    @task
    def backfill_crypto():
        r = requests.get(
            "https://api.coingecko.com/api/v3/coins/bitcoin/market_chart",
            params={"vs_currency": "usd", "days": DAYS, "interval": "daily"},
            timeout=30,
        )
        r.raise_for_status()
        rows = []
        for ts_ms, price in r.json()["prices"]:
            d = datetime.fromtimestamp(ts_ms / 1000, tz=timezone.utc).date()
            rows.append(("coingecko", "BTC/USD", price, d, Json({"timestamp_ms": ts_ms, "price": price})))
        save_many(rows)

    @task
    def backfill_fx():
        rows = []
        today = date.today()
        for i in range(DAYS):
            d = today - timedelta(days=i + 1)
            url = f"https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@{d.isoformat()}/v1/currencies/usd.json"
            r = requests.get(url, timeout=15)
            if r.status_code == 404:
                continue
            r.raise_for_status()
            data = r.json()
            rows.append(("currency_api", "USD/EGP", data["usd"]["egp"], d, Json({"date": data["date"], "egp": data["usd"]["egp"]})))
        save_many(rows)

    backfill_crypto()
    backfill_fx()


backfill_prices()