-------------------------------------
--email to Molly and Nicole when done
-------------------------------------
drop table ceb_dc_oh
;

create table ceb_dc_oh as
select trim(to_char(oh3.sku_nbr,'00000000')) as sku_nbr
      ,trim(to_char(oh3.loc_nbr,'00000')) as loc_nbr
  from prd.oh3_skc_oh@db2magic oh3
      ,prd.is2_itm_sku@db2magic is2
 where is2.dec_sku_nbr = oh3.sku_nbr
   and oh3.loc_nbr in (65,461)
   and cast(oh3.perd_fr_dt as varchar(20)) = '08-NOV-20'
   and oh3.qty > 0
 ;

  CREATE INDEX "AAMFM"."CEB_DC_OH_SKU_NBR" ON "AAMFM"."CEB_DC_OH" ("SKU_NBR") 
  PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
  STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
  PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
  BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
  TABLESPACE "AAMDATA" ;

with skus as (
select distinct ls.style_master_sku
  from list_sku ls
      ,worklist wl
 where ls.style_master_sku = wl.style_master_sku
--   and ls.dept_nbr = 401
--   and ls.subdept_nbr = 803
--   and ls.class_nbr = 130
), oh as (
select oh3.sku_nbr
      ,oh3.loc_nbr
  from ceb_dc_oh oh3
-- where oh3.sku_nbr = skus.style_master_sku
), dupes as (
select wl.style_master_sku
      ,wl.po_nbr
      ,count(*) as cnt
  from worklist wl
      ,skus
 where wl.style_master_sku = skus.style_master_sku
   and wl.status_code != '40'
 group by wl.style_master_sku, wl.po_nbr
 having count(*) > 1
), missingx as (
select skus.style_master_sku
      ,(select count(*)
          from worklist
         where style_master_sku = skus.style_master_sku
           and status_code != '40'
       ) as cnt
  from skus
), missingwithoh as (
select oh.*
  from oh 
 where not exists (
       select 1
         from worklist
        where style_master_sku = oh.sku_nbr
          and po_nbr = oh.loc_nbr
          and (status_code != '40'
           or (status_code = '40' and to_date(status_timestamp) = to_date(current_date)))
       )
)
--select * from missingwithoh order by sku_nbr, loc_nbr
--select * from oh
--select * from missingx order by cnt desc
select wl.style_master_sku, wl.* from dupes, worklist wl where dupes.style_master_sku = wl.style_master_sku and dupes.po_nbr = wl.po_nbr and wl.status_code != '40' order by wl.style_master_sku, status_timestamp
  ;