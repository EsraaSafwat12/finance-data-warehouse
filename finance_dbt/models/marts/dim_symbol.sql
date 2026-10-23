select
    row_number() over (order by symbol) as symbol_key,
    symbol,
    split_part(symbol, '/', 1) as base_currency,
    split_part(symbol, '/', 2) as quote_currency,
    case when symbol = 'BTC/USD' then 'crypto' else 'fx' end as asset_type
from (select distinct symbol from {{ ref('stg_prices') }}) s