with gold as (
    select d.full_date, f.price as xau_usd
    from {{ ref('fact_prices') }} f
    join {{ ref('dim_date') }} d on d.date_key = f.date_key
    join {{ ref('dim_symbol') }} s on s.symbol_key = f.symbol_key
    where s.symbol = 'XAU/USD'
),

usd_egp as (
    select d.full_date, f.price as egp_per_usd
    from {{ ref('fact_prices') }} f
    join {{ ref('dim_date') }} d on d.date_key = f.date_key
    join {{ ref('dim_symbol') }} s on s.symbol_key = f.symbol_key
    where s.symbol = 'USD/EGP'
)

select
    g.full_date,
    round(g.xau_usd::numeric, 2) as gold_usd_per_oz,
    round(u.egp_per_usd::numeric, 4) as egp_per_usd,
    round((g.xau_usd / 31.1035)::numeric, 2) as gold_usd_per_gram,
    round((g.xau_usd / 31.1035 * u.egp_per_usd)::numeric, 2) as gold_egp_per_gram
from gold g
join usd_egp u on u.full_date = g.full_date