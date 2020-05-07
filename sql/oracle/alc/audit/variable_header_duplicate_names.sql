with data as (
select lower(variable_name) as variable_name
  from aam.variable_header
), dupes as (
select variable_name
      ,count(*) as cnt
  from data
 group by variable_name
 having count(*) > 1
)
select vh.variable_name
      ,vh.user_id
      ,vh.variable_key
  from aam.variable_header vh, dupes
 where lower(vh.variable_name) = dupes.variable_name
 order by dupes.variable_name, vh.variable_key
 ;