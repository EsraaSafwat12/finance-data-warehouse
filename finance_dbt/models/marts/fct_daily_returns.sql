with prices as (
    select
        d.full_date,
        s.symbol,
        s.asset_type,
        f.price
    from {{ ref('fact_prices') }} f
    join {{ ref('dim_date') }} d on d.date_key = f.date_key
    join {{ ref('dim_symbol') }} s on s.symbol_key = f.symbol_key
),

with_lag as (
    select
        *,
        lag(price) over (partition by symbol order by full_date) as prev_price
    from prices
)

select
    full_date,
    symbol,
    asset_type,
    price,
    prev_price,
    round((price - prev_price)::numeric, 8) as daily_change,
    round(((price - prev_price) / nullif(prev_price, 0) * 100)::numeric, 4) as daily_change_pct,
    round(avg(price) over (
        partition by symbol order by full_date
        rows between 6 preceding and current row
    )::numeric, 8) as ma_7d,
    round(avg(price) over (
        partition by symbol order by full_date
        rows between 29 preceding and current row
    )::numeric, 8) as ma_30d
from with_lag