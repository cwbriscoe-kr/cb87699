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
