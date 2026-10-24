select
    to_char(d, 'YYYYMMDD')::int as date_key,
    d::date as full_date,
    extract(year from d)::int as year,
    extract(quarter from d)::int as quarter,
    extract(month from d)::int as month,
    trim(to_char(d, 'Month')) as month_name,
    extract(day from d)::int as day,
    trim(to_char(d, 'Day')) as day_name,
    extract(isodow from d) in (6, 7) as is_weekend
from generate_series('2026-07-01'::date, '2027-12-31'::date, interval '1 day') as d