select *
  from prd.pid_whsca whsca
 where src_id in ('791','797','792','794')
   and cas_upc_no = '0400011020813'
--   and itm_no between '900000000' and '950000000'
--   and row_upd_ts > current timestamp - 4 hours
--   and itm_no = '901174420'
fetch first 1000 rows only;

--select count(*) as cnt
select *
  from prd.pid_whsca
where src_id = '794'
  and cas_upc_no = '0400030132818'
--  and txf_cas_upc_no > ' '
--  or txf_con_upc_no > ' '
fetch first 1000 rows only
;

select *
  from prd.pid_whsca
 where src_id  = '797'
   and itm_no = '064701040'
--  where cas_upc_no = '0004122646976'
--  where itm_no = '670845550'
;

select whsca.*
  from prd.pid_whsca whsca
where whsca.src_id  = '791'
  and not exists (
      select 1
        from prd.pid_rmote rmote
       where rmote.cas_upc_no = whsca.cas_upc_no)
--fetch first 10 rows only
;



--FIND XFERS
select rmote.*
  from accp.pid_whsca whsca
      ,accp.pid_rmote rmote
where whsca.src_id      = '791'
  and whsca.itm_no      = rmote.sku_no || '0'
  and whsca.cas_upc_no != rmote.cas_upc_no
  and rmote.row_upd_ts > current timestamp - 3 days
fetch first 10 rows only
;

SELECT DISTINCT(SUBSTR(ITM_NO,1,8)) AS SKU
  FROM ACCP.PID_WHSCA
 WHERE ITM_NO > '00000000' || '0'
 FETCH FIRST 100 ROWS ONLY
  WITH UR
;

select count(*) as cnt
  from accp.pid_whsca
 where row_upd_ts > '2013-08-23-10.30.00.000000'
;

select itm_no, slv_pak_qy
  from prd.pid_whsca
 where src_id = '791'
   and lst_upd_id = '143236'
   and row_upd_ts > '2014-05-20-00.00.00.000000'
;

select itm_no, src_id, cas_upc_no, con_upc_no, txf_cas_upc_no, txf_con_upc_no
  from prd.pid_whsca whsca
 where substr(itm_no,1,8) = '01009415'
;