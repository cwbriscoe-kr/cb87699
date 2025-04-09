with poids as (
     select po_id, count(*) as cnt
       from prd.pi2_rsrv_po_id
      group by po_id
     having count(*) > 1
)
select pi2.*
  from prd.pi2_rsrv_po_id pi2
      ,poids
 where pi2.po_id = poids.po_id
   --and rec_crt_dt < '2015-12-31'
 order by po_id
  with ur;

with poids as (
     select po_id, count(*) as cnt
       from prd.pi2_rsrv_po_id
      group by po_id
     having count(*) > 1
), deletelist as (
     select pi2.po_id
           ,pi2.rec_crt_dt
       from prd.pi2_rsrv_po_id pi2
           ,poids
      where pi2.po_id = poids.po_id
)
select *
  from prd.pi2_rsrv_po_id
 where rec_crt_dt < '2015-12-31'
   and po_id in (
     select po_id from deletelist
     )
with ur;


select count(*)
  from prd.pi2_rsrv_po_id
 where rec_crt_dt < '2017-01-01'
  with ur;
