select is2.*
  from accp.is2_itm_sku is2
      ,accp.fi1_ft_itm fi1
 where is2.itm_nbr = fi1.itm_nbr
   and fi1.rec_stat_cd = '01'
   and is2.rec_stat_cd = '30'
   and is2.sku_typ_cd in ('01','02')
   and fi1.ft_lvl08_cd = '905'
   and sku_nbr < '10000000'
 order by is2.sku_nbr
   ;