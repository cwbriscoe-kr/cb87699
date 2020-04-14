select * from nv_task where status_code in (2);

--delete from nv_task where status_code=2

create table nv_task_bkup as select * from nv_task;

select * from nv_task;

delete
  from nv_task
 where submit_time < '01-JAN-19'
 ;