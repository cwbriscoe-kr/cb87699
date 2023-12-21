with skus as (
select distinct sl4.sku_nbr
  from prd.sl4_sku_loc sl4
      ,prd.is2_itm_sku is2
 where sl4.loc_nbr like '50%'
   and sl4.rec_stat_cd = '01'
   and sl4.sku_nbr  = is2.sku_nbr 
   and is2.sku_typ_cd not in ('DS','08','10','25','30','35','40')
)
select skus.sku_nbr
      ,SUBSTR(CHAR((DECIMAL(RTRIM(va1.art_nbr),14))),2,13) as upc
      ,va1.art_nbr magic_upc
  from skus
      ,prd.va1_vndr_art va1
 where skus.sku_nbr = va1.sku_nbr
 order by va1.sku_nbr, va1.art_nbr 
  with ur;
  