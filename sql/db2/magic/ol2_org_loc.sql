select org_co_id
       ,loc_id
       ,loc_type_cd
   from accp.ol2_org_loc ool 
  where org_co_id = '92'
  ;

select *
  from prd.ol2_org_loc ool 
 --where loc_id = '11672'
   where org_rgn_id = '50'
 order by loc_id
 ;
 
select distinct(org_co_id)
  from prd.ol2_org_loc ool 
 --where loc_id = '11672'
 --order by loc_id
 ;
 