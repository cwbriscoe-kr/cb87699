select *
  from prd.pid_sbcom
 where fam_dpt_cd > '0000'
   for fetch only
 fetch first 1000 row only
 optimize for 1000 row;

select *
  from prd.pid_sbcom
 where lfo_grp_cls_id ='86'
   and lfo_grp_sub_id = '081'
; 

select lfo_grp_cls_id || lfo_grp_sub_id as subcom
      ,cpt_com_cd
      ,cpt_dpt_cd
      ,fam_dpt_cd
      ,fam_cls_cd
      ,fam_sbc_cd
  from prd.pid_sbcom
-- where fam_dpt_cd > '   '
 where cpt_com_cd = '941'
;

select lfo_grp_cls_id
      ,lfo_grp_sub_id
      ,substr(cpt_com_dsc_tx,1,30) as dsc
      ,cpt_com_cd
      ,cpt_dpt_cd
      ,fam_dpt_cd
      ,fam_cls_cd
      ,fam_sbc_cd
--select *
  from prd.pid_sbcom
 where fam_dpt_cd = '0042'
   and fam_cls_cd = '0655'
   and fam_sbc_cd = '0940'
 order by fam_dpt_cd, fam_cls_cd, fam_sbc_cd
;

select lfo_grp_cls_id
      ,lfo_grp_sub_id
      ,cpt_com_cd
      ,cpt_dpt_cd
      ,fam_dpt_cd
      ,fam_cls_cd
      ,fam_sbc_cd
  from prd.pid_sbcom
 where (fam_dpt_cd != '00' || cpt_dpt_cd
    or fam_cls_cd != '0' || cpt_com_cd)
   and fam_dpt_cd > '   '
   and fam_dpt_cd != '9999'
;

select lfo_grp_cls_id
      ,lfo_grp_sub_id
      ,cpt_com_cd
      ,cpt_dpt_cd
      ,cpt_com_dsc_tx
      ,fam_dpt_cd
      ,fam_cls_cd
      ,fam_sbc_cd
  from prd.pid_sbcom
 where cpt_com_cd = '943'
order by cpt_dpt_cd, cpt_com_cd, lfo_grp_cls_id, lfo_grp_sub_id
;

update accp.pid_sbcom
   set fam_sbc_cd     = '0690'
 where lfo_grp_cls_id ='76'
   and lfo_grp_sub_id = '037'
;