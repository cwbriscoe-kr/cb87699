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
select data.sku_nbr
      ,fi1.ft_lvl06_cd as dept
      ,fi1.ft_lvl07_cd as buyer
      ,data.desc_lng_txt as description
      ,data.rec_stat_cd as sku_status
      ,data.old_rec_stat_cd as old_sku_status
      ,data.sku_typ_cd as sku_type
      ,data.rec_crt_dt as create_date
      ,data.rec_alt_ts as altered_timestamp
      ,data.oper_id as operator_id
  from data
      ,prd.fi1_ft_itm fi1
 where data.itm_nbr = fi1.itm_nbr
   and data.rec_stat_cd < '70'
   and fi1.rec_stat_cd = '01'
   and data.cnt = 0
  with ur
  ;
  
select *
  from prd.sc9_set_sku_comp sc9
 where sku_nbr = '01034813'
  with ur
  ;