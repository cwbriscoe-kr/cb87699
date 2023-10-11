select *
  from prd.SA3_SKC_SLE
 where sku_nbr = 81620111
   and loc_nbr = 685
 fetch first 100 rows only
  with ur
  ;

select *
  from prd.SA3_SKC_SLE
 where PERD_FR_DT >= '2023-10-01'
   and rtl_amt > 1000000
 fetch first 100 rows only
  with ur
  ;
  