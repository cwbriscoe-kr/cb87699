drop table if exists oh320200405;

create table oh320200405 as
select TRIM(TO_CHAR(sku_nbr,'00000000')) as sku_nbr
      ,TRIM(TO_CHAR(loc_nbr,'00000')) as loc_nbr
  from PRD.OH3_SKC_OH@DB2MAGIC 
 where LOC_NBR in (65,461)
   and cast(PERD_FR_DT as varchar(20)) = '05-APR-20'
   and qty > 0
 ;

--create table wl_deleted_20200409 as
--select *
delete
  from worklist wl
 where po_nbr in ('00065','00461')
   and status_code = '10'
   and status_timestamp <= '01-JAN-20'
   and not exists (
       select 1
         from oh320200405 oh3
        where oh3.sku_nbr = wl.style_master_sku
          and oh3.loc_nbr = wl.po_nbr
   )
;
  
select * from oh320200405;