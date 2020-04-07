select fi1.ft_lvl06_cd as dept
      ,fi1.ft_lvl08_cd as class
      ,pp1.sku_nbr as sku
      ,is2.DESC_LNG_TXT as description
      ,pp1.chng_nbr as change_number
      ,pp1.fix_unt_prc_amt as temp_price
  from prd.PP1_MDSE_PRC_PND pp1
      ,prd.FI1_FT_ITM       fi1
      ,prd.IS2_ITM_SKU      is2
 where pp1.loc_nbr = '00600'
   and pp1.eff_fr_dt = '2018-11-23'
   and pp1.eff_to_dt = '2018-11-23'
   and pp1.sku_nbr = is2.sku_nbr
   and is2.itm_nbr = fi1.itm_nbr
   and fi1.ft_lvl04_cd in (7, 8)
   and fi1.rec_stat_cd = '01'
 order by fi1.ft_lvl06_cd, fi1.ft_lvl08_cd, pp1.sku_nbr
 ;
