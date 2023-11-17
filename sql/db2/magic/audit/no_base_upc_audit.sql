select fi1.ft_lvl06_cd as dept
      ,fi1.ft_lvl07_cd as buyr
      ,fi1.ft_lvl08_cd as cls
      ,fi1.ft_lvl09_cd as scls
      ,is2.sku_nbr as sku
      ,is2.sku_typ_cd as typ_cd
      ,is2.rec_stat_cd as stat
      ,coalesce((select count(*) from prd.sc9_set_sku_comp sc9 where sc9.sku_nbr = is2.sku_nbr), 0) as comp_skus
      ,is2.desc_lng_txt as desc
  from prd.is2_itm_sku is2
      ,prd.fi1_ft_itm fi1
 where is2.rec_stat_cd < '80'
   and sku_typ_cd not in ('DS','08','10','25','30','35','40')
   and fi1.itm_nbr = is2.itm_nbr 
   and fi1.rec_stat_cd = '01'
   and not exists (
       select 1
         from prd.va1_vndr_art va1
        where va1.sku_nbr = is2.sku_nbr 
          and va1.bas_arl_fl = 'B'
   )
 order by fi1.ft_lvl06_cd
         ,fi1.ft_lvl07_cd 
         ,fi1.ft_lvl08_cd 
         ,fi1.ft_lvl09_cd 
         ,is2.sku_nbr 
  with ur;