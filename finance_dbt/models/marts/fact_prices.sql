select
    d.date_key,
    s.symbol_key,
    src.source_key,
    p.price
from {{ ref('stg_prices') }} p
join {{ ref('dim_date') }} d on d.full_date = p.price_date
join {{ ref('dim_symbol') }} s on s.symbol = p.symbol
join {{ ref('dim_source') }} src on src.source = p.source