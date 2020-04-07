select
  from prd.pid_orden
 where cas_upc_no = '0400030132818'
--   and src_id in ('791','797')
--   and div_cas_stu_cd = 'A'
--order by bil_div_no, src_id
  fetch first 1000 rows only
  with ur
;

with mupc as (
  select '027998202100' as mupc
    from prd.pid_orden
   where 1 = 1
   fetch first 1 row only
),
pupc as (
    select
    CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM(mupc),14)),1,1)
    ||SUBSTR(DIGITS(DECIMAL(RTRIM(mupc),14)),3,1)     
    ||SUBSTR(DIGITS(DECIMAL(RTRIM(mupc),14)),2,1)     
    ||SUBSTR(DIGITS(DECIMAL(RTRIM(mupc),14)),4,10),13)
    as upc
    from mupc
)
select count(*)
  from prd.pid_orden ord, pupc
 where ord.cas_upc_no = pupc.upc
   and ord.src_id in ('791','792','794','797')
--   and ord.div_cas_stu_cd = 'A'
--order by ord.bil_div_no
  with ur
;

select count(*) as cnt
  from accp.pid_orden ord
 where ord.src_id in ('791','792','794','797')
--   and ord.div_cas_stu_cd = 'A'
--order by ord.bil_div_no
  with ur
;

select *
  from prd.pid_whsca
where src_id = '794'
  and cas_upc_no = '0400030132818'
fetch first 1000 rows only