with skutyp as (                                      
  select substr(tbl_elem_id,1,2) as type               
   from prd.td1_tbl_dtl                            
  where tbl_id      = 'F026'                   
    and org_co_nbr  = '1'                      
    and org_rgn_nbr = '00'                     
    and substr(tbl_elem_text,26,1) = 'Y' 
)
select is2.sku_nbr as sku
      ,is2.desc_lng_txt as desc
      ,fi1.ft_lvl06_cd as dept
      ,sl4.mdse_flow_cd 
  from skutyp
      ,prd.is2_itm_sku is2
      ,prd.fi1_ft_itm fi1
      ,prd.sl4_sku_loc sl4
 where is2.sku_typ_cd = skutyp.type
   and is2.itm_nbr = fi1.itm_nbr 
   and is2.sku_nbr = sl4.sku_nbr 
   and is2.rec_stat_cd <= '30'
   and fi1.rec_stat_cd = '01'
   and fi1.ft_lvl06_cd in (68, 79, 82, 85, 89, 95)
   and sl4.rec_stat_cd = '01'
   and sl4.loc_nbr = '20136'
   and sl4.mdse_flow_cd not in ('ALC', 'RMA')
   ;