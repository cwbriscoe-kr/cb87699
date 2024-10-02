select *
  from accp.rs5_rpln_skl rrs 
 --where skl_grp_cd > '50000'
  with ur
  ;
  
/50887

select *
  from prd.rs5_rpln_skl rrs 
 where sku_nbr = '16885042'
 order by skl_grp_cd 
  with ur;

select *
from accp.rs5_rpln_skl rrs
--where sku_nbr = '00854016'
--  and skl_grp_cd = '50887'
with ur
;

select rrs.sku_nbr as sku, count(*) as cnt
from accp.rs5_rpln_skl rrs
--where rrs.skl_rpln_mthd_cd in ('I', 'B', 'S')
where rrs.skl_rpln_mthd_cd = 'D'
group by rrs.sku_nbr
fetch first 100 rows only
with ur
;
