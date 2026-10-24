# Finance Data Warehouse

An end-to-end data engineering project: daily financial prices are pulled from public APIs, orchestrated with **Airflow**, stored in **PostgreSQL**, and modeled into a **Star Schema** with **dbt** (including automated data tests). Everything runs locally on **Docker** using only free tools.

## Architecture

```
APIs (USD/EGP, BTC/USD)
        |
        v
Airflow DAG (daily) ──> raw.api_prices      (raw layer, as received)
        |
        v
dbt staging  ──────────> staging.stg_prices (view)
        |
        v
dbt marts    ──────────> warehouse.dim_date, dim_symbol, dim_source, fact_prices
        |
        v
dbt tests (22)
```

## Tech Stack

| Layer | Tool |
|---|---|
| Orchestration | Apache Airflow 2.10 (CeleryExecutor) |
| Warehouse | PostgreSQL 15 |
| Transformation & testing | dbt-core 1.9 + dbt-postgres |
| Extraction | Python (requests, psycopg2) |
| Infrastructure | Docker Compose |

## Data Sources

- **USD/EGP**: [fawazahmed0/currency-api](https://github.com/fawazahmed0/exchange-api) (free, no API key)
- **BTC/USD**: [CoinGecko](https://www.coingecko.com/en/api) (free tier)

## Data Model (Star Schema)

- `warehouse.fact_prices`: one price per symbol per day (`date_key`, `symbol_key`, `source_key`, `price`)
- `warehouse.dim_date`: calendar attributes (year, quarter, month, weekday, weekend flag)
- `warehouse.dim_symbol`: symbol, base currency, quote currency, asset type
- `warehouse.dim_source`: data source

## Pipelines

- `fetch_prices` (daily): fetch prices from both APIs, upsert into `raw.api_prices` (idempotent via `ON CONFLICT`), then run `dbt run` and `dbt test`.
- `backfill_prices` (manual): loads the last 90 days of history.

## Data Quality

22 dbt tests, including:

- `unique` and `not_null` on all keys
- `relationships` (foreign keys from the fact table to every dimension)
- `accepted_values` on symbols
- custom tests: prices must be positive, and at most one price per symbol per day

## Getting Started

**Prerequisites:** Docker Desktop, Git.

```bash
git clone https://github.com/EsraaSafwat12/finance-data-warehouse.git
cd finance-data-warehouse/airflow
```

1. Create `airflow/.env` containing:

```
AIRFLOW_UID=50000
```

2. Initialize and start the stack:

```bash
docker compose up airflow-init
docker compose up -d --build
```

3. Create the raw layer in the warehouse (one-time):

```bash
docker compose exec -T warehouse-db psql -U warehouse -d finance_dwh < ../sql/init_raw.sql
```

4. Open Airflow at http://localhost:8080 (user `airflow`, password `airflow`), enable and trigger `backfill_prices` once, then enable `fetch_prices`.

5. Connect to the warehouse with any SQL client:

| Setting | Value |
|---|---|
| Host | `127.0.0.1` |
| Port | `5433` |
| Database | `finance_dwh` |
| User / Password | `warehouse` / `warehouse` |

> **Note:** the credentials above are throwaway defaults for local development only. Never commit real secrets; use environment variables or a secrets manager for anything beyond a local demo.

## Example Query

```sql
SELECT d.year, d.month_name, s.symbol,
       ROUND(AVG(f.price), 2) AS avg_price
FROM warehouse.fact_prices f
JOIN warehouse.dim_date   d ON d.date_key   = f.date_key
JOIN warehouse.dim_symbol s ON s.symbol_key = f.symbol_key
GROUP BY d.year, d.month, d.month_name, s.symbol
ORDER BY s.symbol, d.year, d.month;
```

## dbt Documentation

```bash
cd finance_dbt
dbt docs generate
dbt docs serve --port 8081
```

## Project Structure

```
airflow/        Docker Compose, Dockerfile, DAGs, dbt profile (local)
finance_dbt/    dbt project (staging, marts, tests)
sql/            One-time raw layer setup
```

## Possible Next Steps

- Add a Metabase dashboard on top of the warehouse
- Store raw API responses in MongoDB
- Use PySpark for a heavier transformation step
- Add more sources (gold, stocks)
