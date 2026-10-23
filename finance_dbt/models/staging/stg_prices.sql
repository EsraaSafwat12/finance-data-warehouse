select
    symbol,
    price_date,
    price,
    source
from {{ source('raw', 'api_prices') }}