select
    d.year,
    d.month,
    d.month_name,
    s.symbol,
    s.asset_type,
    count(*) as trading_days,
    round(avg(f.price)::numeric, 4) as avg_price,
    round(min(f.price)::numeric, 4) as min_price,
    round(max(f.price)::numeric, 4) as max_price
from {{ ref('fact_prices') }} f
join {{ ref('dim_date') }} d on d.date_key = f.date_key
join {{ ref('dim_symbol') }} s on s.symbol_key = f.symbol_key
group by d.year, d.month, d.month_name, s.symbol, s.asset_type