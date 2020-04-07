select src_id
      ,itm_no
      ,cas_upc_no
      ,con_upc_no
  from prd.pid_whsca
 where itm_no = '00044844' || '0'
   and src_id in ('791', '797')
order by src_id;