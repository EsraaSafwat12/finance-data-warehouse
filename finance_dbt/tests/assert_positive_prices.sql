select *
from {{ ref('fact_prices') }}
where price <= 0