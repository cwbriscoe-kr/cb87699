with e3items as (
    select *
      from accp.rs6_rpln_sku
     where sku_rpln_mthd_cd = 'D'
)
select e3items.srce_id
      ,is2.sku_nbr
      ,is2.desc_shrt_txt
  from e3items
      ,accp.is2_itm_sku is2
 where e3items.sku_nbr = is2.sku_nbr
   and substr(is2.desc_shrt_txt,1,2) = 'OS'
  with ur
;
