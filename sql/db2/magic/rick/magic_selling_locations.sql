select org_co_id 
      ,org_rgn_id
      ,loc_id 
      ,org_unit_nm
      ,loc_type_cd
  from prd.ol2_org_loc ol2
 where loc_clse_dt > current date
   and loc_opn_dt < current date
   and loc_type_cd not in ('02','03','04','06','07','08','09','10','13','60')
 order by org_co_id, org_rgn_id, loc_id
  with ur
  ;