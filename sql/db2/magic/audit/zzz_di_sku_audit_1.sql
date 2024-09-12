with skus as (
select *
  from prd.is2_itm_sku
 where rec_stat_cd in ('60','70')
   and rec_alt_ts < current timestamp - 60 days
), auth as (
select *
  from prd.sl4_sku_loc sl4
      ,skus
 where sl4.sku_nbr = skus.sku_nbr
   and sl4.loc_nbr in ('00065', '00461')
   and sl4.rec_alt_ts < current timestamp - 60 days
   and sl4.rec_stat_cd = '40'
)
select *
  from auth
  with ur
  ;