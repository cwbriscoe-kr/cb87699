select coalesce((
  select count(*)
    from accp.pie_pid_int_errs
  ),0)                                  as terr
      ,coalesce((
  select count(*)
    from (select distinct(sku_nbr)
            from accp.pie_pid_int_errs)
  ),0)                                  as tskuerr
  from accp.tt1_truth_tbl
;

with terr as (
  select sku_nbr
    from accp.pie_pid_int_errs
),
tskuerr as (
  select distinct(sku_nbr)
    from accp.pie_pid_int_errs
),
twhserr as (
  select distinct(sku_nbr)
    from accp.pie_pid_int_errs
   where tran_lvl = 'WHS'
),
tca1err as (
  select distinct(sku_nbr)
    from accp.pie_pid_int_errs
   where tran_lvl = 'CA1'
),
tcu1err as (
  select distinct(sku_nbr)
    from accp.pie_pid_int_errs
   where tran_lvl = 'CU1'
),
tca2err as (
  select distinct(sku_nbr)
    from accp.pie_pid_int_errs
   where tran_lvl = 'CA2'
),
tcu2err as (
  select distinct(sku_nbr)
    from accp.pie_pid_int_errs
   where tran_lvl = 'CU2'
),
data as (
  select coalesce((
         select count(*) from terr
         ),0)                            as terr
        ,coalesce((
         select count(*) from tskuerr
         ),0)                            as tskuerr
        ,coalesce((
         select count(*) from twhserr
         ),0)                            as twhserr
        ,coalesce((
         select count(*) from tca1err
         ),0)                            as tca1err
        ,coalesce((
         select count(*) from tcu1err
         ),0)                            as tcu1err
        ,coalesce((
         select count(*) from tca2err
         ),0)                            as tca2err
        ,coalesce((
         select count(*) from tcu2err
         ),0)                            as tcu2err
    from accp.tt1_truth_tbl
)
select data.*
      ,'tot:' || data.terr || ',' ||
       'sku:' || data.tskuerr || ',' ||
       'whs:' || data.twhserr || ',' ||
       'ca1:' || data.tca1err || ',' ||
       'cu1:' || data.tcu1err || ',' ||
       'ca2:' || data.tca2err || ',' ||
       'cu2:' || data.tcu2err as txt
  from data
;

