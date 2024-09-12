with skus as (
select *
  from prd.is2_itm_sku is2
 where is2.rec_stat_cd = '30'
), price as (
select pm2.*
  from prd.pm2_mdse_prc_mstr pm2
      ,skus
 where pm2.sku_nbr = skus.sku_nbr
   and pm2.perm_prc_typ_cd in ('07','08','67','68')
   and pm2.loc_nbr in ('00065','00461')
   and pm2.rec_alt_ts < current timestamp - 180 days
), auth as (
select sl4.*
  from prd.sl4_sku_loc sl4
      ,price
 where sl4.sku_nbr = price.sku_nbr
   and sl4.loc_nbr = price.loc_nbr
   and sl4.rec_stat_cd in ('01','40')
   and sl4.rec_alt_ts < current timestamp - 180 days
), oorder as (
select is2.sku_nbr as sku_nbr
      ,ol2.loc_id as loc_nbr
  from prd.is2_itm_sku is2
      ,prd.ol2_org_loc ol2
      ,prd.oo3_skc_oo oo3
      ,price
 where is2.sku_nbr = price.sku_nbr
   and ol2.loc_id = price.loc_nbr
   and oo3.sku_nbr = is2.dec_sku_nbr 
   and oo3.loc_nbr = ol2.dec_loc_nbr
   and oo3.qty > 0.0
), report as (
select skus.sku_nbr as sku
      ,price.loc_nbr as loc
      ,skus.desc_lng_txt as desc
      ,price.perm_prc_typ_cd as prc_typ
      ,skus.rec_stat_cd as sku_sts
      ,auth.rec_stat_cd as loc_sts
      ,fi1.ft_lvl06_cd as dept
      ,fi1.ft_lvl07_cd as buyr
      ,fi1.ft_lvl08_cd as cls
      ,fi1.ft_lvl09_cd as scls
  from skus, price, auth
      ,prd.fi1_ft_itm fi1
 where skus.sku_nbr = price.sku_nbr
   and auth.sku_nbr = skus.sku_nbr
   and auth.loc_nbr = price.loc_nbr
   and fi1.itm_nbr = skus.itm_nbr
   and fi1.rec_stat_cd = '01'
   and not exists (
       select 1
         from oorder
        where oorder.sku_nbr = skus.sku_nbr
          and oorder.loc_nbr = price.loc_nbr
   )
)
select *
  from report
  with ur
  ;