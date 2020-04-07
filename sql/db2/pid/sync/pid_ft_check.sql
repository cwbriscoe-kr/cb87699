select sbcom.fam_dpt_cd
      ,sbcom.fam_cls_cd
      ,sbcom.fam_sbc_cd
  from accp.pid_pdtca pdtca
      ,accp.pid_sbcom sbcom
 where sbcom.lfo_grp_cls_id = pdtca.lfo_grp_cls_id
   and sbcom.lfo_grp_sub_id = pdtca.lfo_grp_sub_id
   and sbcom.fam_dpt_cd between '0000' and '0999'
   and sbcom.fam_cls_cd between '0000' and '0999'
   and sbcom.fam_sbc_cd between '0000' and '0999'
   and pdtca.cas_upc_no = '0400008443144'
;