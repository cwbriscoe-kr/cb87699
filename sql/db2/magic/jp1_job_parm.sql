select *
  from prd.JP1_JOB_PARM 
 where job_nm = 'E3SRTFLT' 
  with ur
  ;
  
select *
  from prd.JP1_JOB_PARM 
 where job_nm = 'SOB1016' 
  with ur
  ;

select *
from accp.JP1_JOB_PARM
where job_nm = 'APDT-RM'
order by seq_nbr
with ur
;

select *
from accp.JP1_JOB_PARM
where job_nm = 'APDT-RM'
  and seq_nbr = '140'
 with ur;