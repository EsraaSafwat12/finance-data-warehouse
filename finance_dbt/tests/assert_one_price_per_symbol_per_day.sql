select distinct p.symbol
from {{ ref('stg_prices') }} p
left join {{ ref('dim_symbol') }} s on s.symbol = p.symbol
where s.symbol is null