select rmote.sku_no as sku_nbr
      ,pdtco.con_dsc_tx as pid_pdtco_value
      ,pdtca.cas_dsc_tx as pid_pdtca_value
      ,rmote.itm_abb_dsc_tx as magic_short_desc
      ,rmote.itm_dsc_tx as magic_long_desc
  from prd.pid_pdtco pdtco
      ,prd.pid_pdtca pdtca
      ,prd.pid_rmote rmote
 where pdtco.con_upc_no = rmote.con_upc_no
   and pdtca.cas_upc_no = rmote.cas_upc_no
   and rmote.sku_no in ('39030511', '59030515')
  ;
  