with fm as (
  select distinct(cas_upc_no) as cas_upc_no
    from prd.pid_orden
   where bil_div_no = '701'
     and div_cas_stu_cd != 'D'
),
nonfm as (
  select distinct(cas_upc_no) as cas_upc_no
    from prd.pid_orden
   where bil_div_no not in ('700','701','702','703','704','705','706','707','708','709')
     and div_cas_stu_cd != 'D'
),
combined as (
  select fm.cas_upc_no
    from fm, nonfm
   where fm.cas_upc_no = nonfm.cas_upc_no
)
select ord.*
  from combined, prd.pid_orden ord
 where combined.cas_upc_no = ord.cas_upc_no
 order by ord.cas_upc_no, ord.bil_div_no
fetch first 100000 rows only
;

select distinct(bil_div_no) as div
  from prd.pid_orden
-- where bil_div_no = '701'
--   and div_cas_stu_cd != 'D'
order by bil_div_no
fetch first 1000 rows only
;