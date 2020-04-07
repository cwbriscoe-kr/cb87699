select *
  from accp.pid_mfgid
-- where mfr_gtin_cnv_dt > '0001-01-01'
--   and mfg_upc_no > '01000000'
-- where mfg_upc_no like '%7049856%'
--   where mfg_upc_no like '%798193%'
   where mfg_upc_no = '00079578'
--order by mfg_upc_no desc
fetch first 1000 rows only
;
