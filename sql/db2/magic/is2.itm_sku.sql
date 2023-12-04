select *
  from prd.IS2_ITM_SKU
 --where prc_typ_cd in ('07','08','67','68')
 where sku_nbr = '04676843'
  with ur
 ;
 
select *
  from prd.is2_itm_sku iis 
 where sku_nbr = '61754744'
  with ur 
  ;