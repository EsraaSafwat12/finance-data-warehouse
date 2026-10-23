select
    row_number() over (order by source) as source_key,
    source
from (select distinct source from {{ ref('stg_prices') }}) s