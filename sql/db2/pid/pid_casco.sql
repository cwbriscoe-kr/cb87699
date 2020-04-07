select *
  from prd.pid_casco
 where cas_upc_no = '1801640401231'
-- where con_upc_no = '0003218200005'
-- where con_upc_no > '10000000000000'
--where cpt_con_cst_am > 0
 -- where cas_con_qy != 1
order by cas_upc_no, con_typ_cd, con_upc_no
fetch first 1000 rows only
;

select cas_upc_no
  from accp.pid_casco
 where con_typ_cd = '1'
   and substr(cas_upc_no,1,3) != '040'
order by con_upc_no
fetch first 1000 rows only
;

select *
  from prd.pid_casco
 where con_upc_no in (
'0060135065462',
'0060135065463',
'0060135065876',
'0060135065877',
'0060135065878',
'0060135065879',
'0060135067695',
'0060135067696',
'0060135067697'
)