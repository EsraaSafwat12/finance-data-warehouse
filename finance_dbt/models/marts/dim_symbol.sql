select
    row_number() over (order by symbol) as symbol_key,
    symbol,
    base_currency,
    quote_currency,
    asset_type,
    display_name
from {{ ref('symbols') }}