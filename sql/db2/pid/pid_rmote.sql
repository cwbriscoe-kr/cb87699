  select count(*) as cnt	
    from accp.pid_rmote
--   where ROW_UPD_TS = '2000-01-01-00.00.00.000000'
--   where fyt_chg_eff_dt = '2015-04-08'
--   where sku_no = '92530645'
--   where cas_upc_no = '0808198802785'
--order by cas_upc_no, con_upc_no
--order by row_upd_ts
fetch first 1000 rows only;

select *
  from prd.pid_rmote
 where cas_upc_no = '2701997842345'
   and con_typ_cd = '1'
   and sys_id = 'MAG'
;

select count(*) as cnt
  from prd.pid_rmote
 where stu_cd = 'D'
  with ur
;

select distinct(sku_no) as sku_no
  from accp.pid_rmote
;

  select *
    from accp.pid_rmote
   where days(current timestamp) - days(row_upd_ts) > 60
     and row_upd_ts != '2000-01-01-00.00.00.000000'
fetch first 1000 rows only;

delete from accp.pid_rmote where sku_no = '85853140';

update accp.pid_rmote set row_upd_ts = '2010-01-01-00.00.00.000000' where sku_no = '65009642';

update accp.pid_rmote set row_upd_ts = current_timestamp;