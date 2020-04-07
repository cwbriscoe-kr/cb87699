select *
  from prd.pid_stage
order by row_add_ts desc
-- where row_add_ts > current timestamp - 1 day
-- fetch first 1000 rows only
;

delete from accp.pid_stage;