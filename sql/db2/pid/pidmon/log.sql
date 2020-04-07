select *
  from accp.jl1_job_log
 where job_nm = 'UACPID00'
   and step_nm = 'MSGLOG'
order by beg_ts desc
fetch first 1000 rows only
;

select count(*) as cnt
  from accp.jl1_job_log
 where job_nm = 'UACPID00'
   and step_nm = 'MSGLOG'
;