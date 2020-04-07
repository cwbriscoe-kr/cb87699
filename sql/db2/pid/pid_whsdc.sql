select *
  from prd.pid_whsdc whsdc
-- where src_id = '791'
 --  and cas_upc_no = '0400067823949'
 --where cas_upc_no = '0002994450004'
--   and WHSDC.OLP_DCN_DT > '0001-01-01'
--   and WHSDC.CRP_DEL_DT  > '0001-01-01'
fetch first 1000 rows only;

select count(*) as cnt
  from accp.pid_whsdc
 where src_id = '791';

select whsca.itm_no
  from accp.pid_whsdc whsdc
      ,accp.pid_whsca whsca
 where whsca.src_id = '791'
   and whsca.src_id = whsdc.src_id
   and whsca.cas_upc_no = whsdc.cas_upc_no
   and WHSDC.OLP_DCN_DT > '0001-01-01'
   and WHSDC.CRP_DEL_DT  = '0001-01-01'
fetch first 1000 rows only;

select whs1.*
  from accp.pid_whsca whs1
 where whs1.src_id = '791'
   and substr(whs1.itm_no,9,1) = '0'
   and exists(
       select 1
         from accp.pid_whsca whs2
        where whs2.cas_upc_no = whs1.cas_upc_no
          and whs2.src_id     not in ('791','797')
          and whs2.bil_stu_cd != '03'
          and not exists(
              select 1
                from accp.pid_orden ord
               where ord.cas_upc_no = whs2.cas_upc_no
                 and ord.src_id     not in ('791','797')
              )
        fetch first 1 row only
       )
  with ur
 fetch first 1 row only
   