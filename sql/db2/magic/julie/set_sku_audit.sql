with data as(
select coalesce((
       select count(*)
         from prd.sc9_set_sku_comp sc9
        where sc9.sku_nbr = is2.sku_nbr  
                ),0) as cnt
      ,is2.*
  from prd.is2_itm_sku is2
 where sku_typ_cd = '55'
)
select cnt as comp_sku_cnt
      ,sku_nbr
      ,sku_typ_cd
      ,desc_lng_txt
      ,rec_stat_cd
      ,old_rec_stat_cd
      ,rec_crt_dt
      ,rec_alt_ts
  from data
 where cnt = 0
  with ur 
  ;
  
select *
  from prd.sc9_set_sku_comp sc9
 where sku_nbr = '01034813'
  with ur
  ;