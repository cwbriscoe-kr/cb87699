select is2.sku_nbr     as sku
      ,fi1.ft_lvl06_cd as dpt
      ,fi1.ft_lvl08_cd as cls
      ,fi1.ft_lvl09_cd as scl
  from prd.VA1_VNDR_ART va1
      ,prd.IS2_ITM_SKU  is2
      ,prd.FI1_FT_ITM   fi1
 where is2.sku_nbr      = va1.sku_nbr
   and fi1.itm_nbr      = is2.itm_nbr
   and fi1.rec_stat_cd  = '01'
   and va1.art_4680_nbr = 7779219912
   ;


select * from prd.FI1_FT_ITM;