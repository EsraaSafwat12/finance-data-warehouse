CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS warehouse;

CREATE TABLE IF NOT EXISTS raw.api_prices (
    id           BIGSERIAL PRIMARY KEY,
    source       TEXT NOT NULL,
    symbol       TEXT NOT NULL,
    price        NUMERIC(20, 8) NOT NULL,
    price_date   DATE NOT NULL,
    payload      JSONB,
    ingested_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (source, symbol, price_date)
);