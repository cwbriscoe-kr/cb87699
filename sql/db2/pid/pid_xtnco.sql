select *
  from prd.pid_xtnco
 where fmy_sku_no = '86021616'
 --where gtin_no = '0040092575110'
-- where fmy_sku_no <= space(8)
 --  and con_out_dt > '0001-01-01'
--   and con_out_dt > current date
 fetch first 100 rows only
  with ur
;

select *
  from prd.pid_xtnco
 where GTIN_NO = '0007792408216'
  with ur
;

select *
  from prd.pid_xtnco
 where con_clx_tx > ' '
   and con_out_dt > '0001-01-01'
   and row_upd_ts > current_timestamp - 5 days
 fetch first 100 rows only
  with ur
;

update accp.pid_xtnco
   set con_clx_tx = ' '
 where con_upc_no = '0401098188345'
;

select *
  from accp.pid_xtnco
 fetch first 1000 rows only
;

select con_upc_no, fmy_sku_no, fmy_brn_nam_tx
  from krgnetdb25.pidsyst.pidxtnco
 where con_upc_no = '0701342422424'
-- where fmy_sku_no <= space(8)
--   and sku_typ_cd > space(2)
  with ur
 fetch first 100 rows only
;

select *
--  from prd.pid_xtnco
from krgnetdb20.pid.pidxtnco
 where con_upc_no in (
'0600634829061'
)
  with ur
 fetch first 1000 rows only
;