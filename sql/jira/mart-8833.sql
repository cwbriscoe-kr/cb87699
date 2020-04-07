select rmote.sku_no
      ,rmote.itm_dsc_tx
      ,rmote.stu_cd
      ,rmote.cas_upc_no
      ,rmote.con_upc_no
      ,rmote.fam_dpt_cd as mag_dpt
      ,rmote.fam_cls_cd as mag_cls
      ,rmote.fam_sbc_cd as mag_sbc
      ,(select sbcom2.lfo_grp_cls_id||sbcom2.lfo_grp_sub_id
         from prd.pid_sbcom sbcom2
        where sbcom2.fam_dpt_cd = rmote.fam_dpt_cd
          and sbcom2.fam_cls_cd = rmote.fam_cls_cd
          and sbcom2.fam_sbc_cd = rmote.fam_sbc_cd) as mag_sbcom
      ,sbcom.fam_dpt_cd as pid_dpt
      ,sbcom.fam_cls_cd as pid_cls
      ,sbcom.fam_sbc_cd as pid_sbc
      ,sbcom.lfo_grp_cls_id||sbcom.lfo_grp_sub_id as pid_sbcom
  from prd.pid_rmote rmote
      ,prd.pid_pdtca pdtca
      ,prd.pid_sbcom sbcom
 where rmote.cas_upc_no = pdtca.cas_upc_no
   and pdtca.lfo_grp_cls_id = sbcom.lfo_grp_cls_id
   and pdtca.lfo_grp_sub_id = sbcom.lfo_grp_sub_id
   and (sbcom.fam_dpt_cd != rmote.fam_dpt_cd
    or  sbcom.fam_cls_cd != rmote.fam_cls_cd
    or  sbcom.fam_sbc_cd != rmote.fam_sbc_cd)
   and rmote.fam_dpt_cd = '0076'
 order by rmote.fam_dpt_cd, rmote.fam_cls_cd, rmote.fam_sbc_cd, cas_upc_no, con_upc_no
;