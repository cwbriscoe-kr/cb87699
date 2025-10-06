with skutyp as (
  select substr(tbl_elem_id,1,2) as type
   from td1_tbl_dtl
  where tbl_id      = 'F026'
    and org_co_nbr  = '1'
    and org_rgn_nbr = '00'
    and substr(tbl_elem_text,26,1) = 'Y'
)
select cal.prd_yy as fiscal_year
      ,cal.prd_nbr as fiscal_period
      ,fi1.ft_lvl06_cd as dept
      ,count(*) as new_skus
  from skutyp
      ,is2_itm_sku is2
      ,fi1_ft_itm fi1
      ,cal_prd_calendar cal
 where is2.sku_typ_cd = skutyp.type
   and is2.itm_nbr = fi1.itm_nbr
   and is2.rec_crt_dt =  cal.greg_dt
   and cal.prd_yy >= 2024
 group by cal.prd_yy, cal.prd_nbr, fi1.ft_lvl06_cd
 order by cal.prd_yy, cal.prd_nbr, count(*) desc
   ;