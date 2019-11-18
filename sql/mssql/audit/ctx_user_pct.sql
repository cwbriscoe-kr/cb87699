with user_processes as (
select *
  from sys.sysprocesses
 where (hostname like 'OF060%' 
    or  hostname like 'OF701%' 
    or  hostname like 'N060CTX%')
), totusers as (
select cast(count(*) as float) as cnt from user_processes
), ctxusers as (
select cast(count(*) as float) as cnt from user_processes where hostname like 'N060CTX%'
), ctxuserpct as (
select (100.0 * ctxusers.cnt / totusers.cnt) as pct from ctxusers, totusers
)
select * from ctxuserpct