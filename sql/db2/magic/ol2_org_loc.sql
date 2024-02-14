select org_co_id
       ,loc_id
       ,loc_type_cd
   from accp.ol2_org_loc ool 
  where org_co_id = '92'
  ;

select *
  from prd.ol2_org_loc ool 
 --where loc_id = '11672'
   where loc_id like '50%'
     and loc_clse_dt > current date
     and loc_opn_dt < current date
 order by loc_id
 ;
 
select distinct(org_co_id)
  from prd.ol2_org_loc ool 
 --where loc_id = '11672'
 --order by loc_id
 ;
 
select *
  from prd.ol2_org_loc ol2
 where loc_id in ('50883','50894','50972')
  with ur;


select distinct loc_type_cd
  from prd.ol2_org_loc ool 
  with ur;

select org_co_id 
      ,org_rgn_id
      ,loc_id 
      ,org_unit_nm
      ,loc_type_cd
  from prd.ol2_org_loc ol2
 where loc_clse_dt > current date
   and loc_opn_dt < current date
   and loc_type_cd not in ('02','03','04','06','07','08','09','10','13')
 order by org_co_id, org_rgn_id, loc_id
  with ur
  ;
 