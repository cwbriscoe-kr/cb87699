select *
  from prd.PM2_MDSE_PRC_MSTR pmpm 
 where sku_nbr = '43425617'
   --where loc_nbr in ('00065', '00461')
  with ur
 ;
 
select *
  from prd.pm2_mdse_prc_mstr
 where perm_prc_typ_cd in ('07','08','67','68')
   and loc_nbr in ('00065','00461')
  with ur
  ;