drop table whs;

with whsdat as (
select case
       when txf_cas_upc_no > space(13) then
         txf_cas_upc_no
       else
         cas_upc_no
       end as cas_upc_no
      ,substr(itm_no,1,8) as sku_nbr
  from prd.pid_whsca whsca
where whsca.src_id  = '791'
)
select *
  from whsdat
 where not exists (
      select 1
        from prd.pid_rmote rmote
       where rmote.cas_upc_no = whsdat.cas_upc_no)
--fetch first 10 rows only
;
--export above to rmote.whs

select distinct(sku_nbr)
  from prd.pie_pid_int_errs
;
--export above to rmote.err

select sku_nbr
  from whs
 where not exists (
       select 1
         from err
        where err.sku_nbr = whs.sku_nbr)
