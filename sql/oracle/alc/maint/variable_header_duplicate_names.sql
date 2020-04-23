with dupes as (
select variable_name
      ,count(*) as cnt
  from variable_header
 group by variable_name
 having count(*) > 1
)
select *
  from variable_header vh, dupes
 where vh.variable_name = dupes.variable_name
 order by vh.variable_name, vh.variable_key
 ;