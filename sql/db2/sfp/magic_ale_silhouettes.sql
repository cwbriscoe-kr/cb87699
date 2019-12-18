select is2.itm_nbr
      ,is2.sku_nbr
      ,id1.silhouette_typ_cd as silhouette
      ,id1.sub_silhouette_cd as subsilhouette
  from prd.IS2_ITM_SKU is2
      ,prd.ID1_ITM_DTL id1
      ,prd.FI1_FT_ITM fi1
 where is2.itm_nbr = id1.itm_nbr
   and is2.itm_nbr = fi1.itm_nbr
   and is2.rec_stat_cd in ('20','30','40')
   and is2.sku_typ_cd in ('01','02','03','04','45','55','64','68','69')
   and fi1.ft_lvl04_cd = 9
   and fi1.rec_stat_cd = '01'
 order by itm_nbr, sku_nbr
  ;