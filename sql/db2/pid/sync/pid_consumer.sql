select casco.cas_upc_no              as cas_upc_no
      ,casco.con_upc_no              as con_upc_no
      ,casco.cas_con_qy              as cas_pak_qy
      ,casco.con_typ_cd              as con_typ_cd
      ,pdtco.con_dsc_abb_tx_2        as con_dsc_abb_tx
      ,substr(pdtco.con_dsc_tx,1,20) as con_dsc_tx
      ,case pdtco.fsa_fl
       when 'Y' then
         'Y'
       else
         ' '
       end                           as fsa_fl
      ,casco.cas_con_cnt_qy          as cpn_sku_qy
      ,casco.cpt_con_cst_am          as cpn_sku_cst_am
  from accp.pid_casco casco
      ,accp.pid_pdtco pdtco
 where casco.cas_upc_no = '0400002194646'
   and casco.con_upc_no = pdtco.con_upc_no
 order by con_typ_cd desc, con_upc_no
;