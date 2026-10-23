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

CREATE TABLE staging.prices AS
SELECT DISTINCT ON (symbol, price_date)
    symbol, price_date, price, source
FROM raw.api_prices
ORDER BY symbol, price_date,
         CASE source WHEN 'open_er_api' THEN 1 WHEN 'coingecko' THEN 1 ELSE 2 END;

CREATE TABLE warehouse.dim_date (
    date_key     INT PRIMARY KEY,
    full_date    DATE NOT NULL UNIQUE,
    year         INT NOT NULL,
    quarter      INT NOT NULL,
    month        INT NOT NULL,
    month_name   TEXT NOT NULL,
    day          INT NOT NULL,
    day_name     TEXT NOT NULL,
    is_weekend   BOOLEAN NOT NULL
);

INSERT INTO warehouse.dim_date
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT, d,
    EXTRACT(YEAR FROM d), EXTRACT(QUARTER FROM d), EXTRACT(MONTH FROM d),
    TO_CHAR(d, 'FMMonth'), EXTRACT(DAY FROM d), TO_CHAR(d, 'FMDay'),
    EXTRACT(ISODOW FROM d) IN (6, 7)
FROM generate_series('2026-07-01'::date, '2026-12-31'::date, '1 day') AS d;

CREATE TABLE warehouse.dim_symbol (
    symbol_key      SERIAL PRIMARY KEY,
    symbol          TEXT NOT NULL UNIQUE,
    base_currency   TEXT NOT NULL,
    quote_currency  TEXT NOT NULL,
    asset_type      TEXT NOT NULL
);

INSERT INTO warehouse.dim_symbol (symbol, base_currency, quote_currency, asset_type) VALUES
    ('USD/EGP', 'USD', 'EGP', 'fx'),
    ('BTC/USD', 'BTC', 'USD', 'crypto');

CREATE TABLE warehouse.dim_source (
    source_key  SERIAL PRIMARY KEY,
    source      TEXT NOT NULL UNIQUE
);

INSERT INTO warehouse.dim_source (source)
SELECT DISTINCT source FROM raw.api_prices;

CREATE TABLE warehouse.fact_prices (
    price_id    BIGSERIAL PRIMARY KEY,
    date_key    INT NOT NULL REFERENCES warehouse.dim_date (date_key),
    symbol_key  INT NOT NULL REFERENCES warehouse.dim_symbol (symbol_key),
    source_key  INT NOT NULL REFERENCES warehouse.dim_source (source_key),
    price       NUMERIC(20, 8) NOT NULL,
    loaded_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (date_key, symbol_key)
);

INSERT INTO warehouse.fact_prices (date_key, symbol_key, source_key, price)
SELECT dd.date_key, ds.symbol_key, dsrc.source_key, sp.price
FROM staging.prices sp
JOIN warehouse.dim_date   dd   ON dd.full_date = sp.price_date
JOIN warehouse.dim_symbol ds   ON ds.symbol    = sp.symbol
JOIN warehouse.dim_source dsrc ON dsrc.source  = sp.source;