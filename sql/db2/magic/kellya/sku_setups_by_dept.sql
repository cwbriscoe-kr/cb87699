with skutyp as (                                      
  select substr(tbl_elem_id,1,2) as type               
   from td1_tbl_dtl
  where tbl_id      = 'F026'                   
    and org_co_nbr  = '1'                      
    and org_rgn_nbr = '00'                     
    and substr(tbl_elem_text,26,1) = 'Y' 
)
select fi1.ft_lvl06_cd as dept
      ,count(*) as cnt
  from skutyp
      ,is2_itm_sku is2
      ,fi1_ft_itm fi1
 where is2.sku_typ_cd = skutyp.type
   and is2.itm_nbr = fi1.itm_nbr 
   and fi1.rec_stat_cd = '01'
   and is2.rec_crt_dt between '2025-02-04' and '2025-05-25'
 group by fi1.ft_lvl06_cd
 order by count(*) desc
   ;