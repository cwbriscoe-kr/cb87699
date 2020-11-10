select SUBSTR(TBL_ELEM_TEXT,23,1) as flg
      ,td1.*
  from accp.td1_tbl_dtl td1
 where tbl_id = 'T001'
 ;
 
select SUBSTR(TBL_ELEM_TEXT,23,1) as flg
  from accp.td1_tbl_dtl td1
 where tbl_id = 'T001'
   and tbl_elem_id = '70'
 ;
 
select *
  from accp.td1_tbl_dtl td1
 where tbl_id = 'T032'
 ;
 
select is2.*
  from accp.is2_itm_sku is2
      ,accp.id1_itm_dtl id1
 where is2.itm_nbr = id1.itm_nbr
   and is2.rec_stat_cd = '70'
   and exists (
       select 1
         from accp.is2_itm_sku is3
        where is3.itm_nbr = is2.itm_nbr 
          and is3.rec_stat_cd < '40'
   );
   
select is2.itm_nbr, is2.sku_nbr, is2.rec_stat_cd
  from accp.is2_itm_sku is2
 where itm_nbr = '00187596'
 ;
 
with chngs as (
select chng_nbr, count(*) as cnt
  from accp.cs6_chng_sku
group by chng_nbr
having count(*) < 10
), data as (
select cs6.chng_nbr
  from accp.is2_itm_sku is2
      ,accp.cs6_chng_sku cs6
      ,chngs
 where is2.sku_nbr = cs6.sku_nbr
   and is2.rec_stat_cd = '70'
   and cs6.chng_nbr = chngs.chng_nbr
   and exists (
       select 1
         from accp.is2_itm_sku is22
             ,accp.cs6_chng_sku cs66
        where is22.sku_nbr = cs66.sku_nbr 
          and cs66.chng_nbr = cs6.chng_nbr
          and is22.rec_stat_cd < '40'
   )
)
select distinct chng_nbr 
  from data
;
   
select is2.*
  from accp.is2_itm_sku is2
      ,accp.cs6_chng_sku cs6
 where is2.sku_nbr = cs6.sku_nbr 
   and cs6.chng_nbr = 50111291
   --and is2.rec_stat_cd >= '70'
   ;
--3964981
--6011291
 
select *
  from accp.cs6_chng_sku 
 where chng_nbr = 94444681
 ;
 
select *
  from accp.br1_pm_btch_rqst 
 where chng_nbr = 94444681
 ;
 
 select *
   from krgnetdb25.pidsyst.pidrmote
   ;