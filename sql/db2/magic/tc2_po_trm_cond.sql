select *
  from tc2_po_trm_cond
  with ur;
  
select distinct(org_co_id)
  from tc2_po_trm_cond
  with ur;

select *
  from tc2_po_trm_cond
 where po_id = '000040115251'
  with ur;

update tc2_po_trm_cond
   set ord_srce_cd = 'RM'
 where po_id = '000040115251'
;
