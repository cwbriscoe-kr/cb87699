select sbcom.fam_dpt_cd
      ,sbcom.fam_cls_cd
      ,sbcom.fam_sbc_cd
  from prd.pid_sbcom sbcom
      ,prd.pid_pdtca pdtca
 where pdtca.lfo_grp_cls_id = sbcom.lfo_grp_cls_id
   and pdtca.lfo_grp_sub_id = sbcom.lfo_grp_sub_id
   and pdtca.cas_upc_no     = '8002667668982'
  with ur
;