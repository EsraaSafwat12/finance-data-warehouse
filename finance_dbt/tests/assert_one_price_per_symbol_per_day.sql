select date_key, symbol_key, count(*) as n
from {{ ref('fact_prices') }}
group by date_key, symbol_key
having count(*) > 1