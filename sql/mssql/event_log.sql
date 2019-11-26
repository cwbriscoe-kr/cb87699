with errors as (
select *
  from ix_sys_event_log with (nolock)
 where DBTime > '2019-10-25 00:00:00.000'
   and EventID = 3002015
), details as (
select DBTime
      ,DBUser
      ,case 
       when DBMachine like '%N060CTX%' THEN
         'CTX'
       when DBMachine like 'OF060%' THEN
         '060'
       when DBMachine like 'OF701%' THEN
         '701'
       else 
         DBMachine
       end as Loc
      ,Description
      ,Detail
  from errors
), stats as (
select loc
      ,count(*) as cnt
  from details
 group by loc
)
select top (1000) *
  from details
 where 1=1
 --and Detail like '%query processor%'
 --and DBUser = 'KROGER\SAS9399'
 and Loc = 'CTX'
 order by DBTime desc
 --order by cnt desc
  ;