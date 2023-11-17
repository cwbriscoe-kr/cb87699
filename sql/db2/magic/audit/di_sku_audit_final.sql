select fi1.ft_lvl06_cd as dept
      ,fi1.ft_lvl07_cd as buyr
      ,is2.sku_nbr as sku
      ,va1.art_nbr as bas_upc
      ,is2.desc_lng_txt as desc
      ,fi1.ft_lvl08_cd as cls
      ,fi1.ft_lvl09_cd as scls
      ,pm2.loc_nbr as loc
      ,pm2.perm_prc_typ_cd as prc_typ
      ,is2.rec_stat_cd as sku_sts
      ,sl4.rec_stat_cd as loc_sts
  from prd.is2_itm_sku is2
      ,prd.pm2_mdse_prc_mstr pm2 
      ,prd.sl4_sku_loc sl4
      ,prd.fi1_ft_itm fi1
      ,prd.va1_vndr_art va1
      ,prd.ol2_org_loc ol2
 where is2.rec_stat_cd = '30'
   and fi1.itm_nbr = is2.itm_nbr 
   and fi1.rec_stat_cd = '01'
   and pm2.sku_nbr = is2.sku_nbr
   and pm2.perm_prc_typ_cd in ('07','08','67','68')
   and pm2.loc_nbr in ('00065','00461')
   and pm2.rec_alt_ts < current timestamp - 180 days
   and sl4.sku_nbr = is2.sku_nbr
   and sl4.loc_nbr = pm2.loc_nbr
   and sl4.rec_stat_cd in ('01','40')
   and sl4.rec_alt_ts < current timestamp - 180 days
   and va1.sku_nbr = is2.sku_nbr 
   and va1.bas_arl_fl = 'B'
   and ol2.loc_id = pm2.loc_nbr 
   and not exists (
       select 1
         from prd.oo3_skc_oo oo3
        where oo3.sku_nbr = is2.dec_sku_nbr 
          and oo3.loc_nbr = ol2.dec_loc_nbr 
          and oo3.qty > 0.0
    )
 order by fi1.ft_lvl06_cd 
         ,fi1.ft_lvl07_cd 
         ,is2.sku_nbr 
  with ur;