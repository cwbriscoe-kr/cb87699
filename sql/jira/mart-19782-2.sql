select *
  from prd.SL4_SKU_LOC
 where loc_nbr in ('00065','00461')
   and rec_stat_cd = '01'
   and sku_nbr > '10000000'

with locs as (
select is2.sku_nbr
  from prd.SL4_SKU_LOC sl4
      ,prd.IS2_ITM_SKU is2
 where sl4.loc_nbr > '20000'
   and sl4.loc_nbr < '50000'
   and sl4.rec_stat_cd = '01'
   and sl4.sku_nbr = is2.sku_nbr
   and is2.rec_stat_cd = '30'
   and is2.SKU_TYP_CD in ('01','02')
   and is2.sku_nbr < '50000000'
), skus as (
select sku_nbr as sku
  from locs
 group by sku_nbr
), results as (
select *
  from skus
 where exists (
       select 1
         from prd.SL4_SKU_LOC sl4
        where sl4.sku_nbr = skus.sku
          and sl4.loc_nbr = '00065'
          and sl4.rec_stat_cd in ('01','40')
       )
   and exists (
       select 1
         from prd.SL4_SKU_LOC sl4
        where sl4.sku_nbr = skus.sku
          and sl4.loc_nbr = '00461'
          and sl4.rec_stat_cd in ('01','40')
       )
)
select * from results
  with ur
   ;

select *
  from prd.IS2_ITM_SKU
 where sku_typ_cd = '55'
   and rec_stat_cd = '30'
   ;

SELECT ROWNUMBER() OVER(ORDER BY TBL_ELEM_ID) AS STPNUM
      ,SUBSTR(TBL_ELEM_ID,1,2)                AS STP   
 FROM prd.TD1_TBL_DTL                                      
WHERE TBL_ID      = 'F026'                             
  AND ORG_CO_NBR  = '1'                                
  AND ORG_RGN_NBR = '00'                               
  AND SUBSTR(TBL_ELEM_TEXT,26,1) = 'Y'                 
ORDER BY TBL_ELEM_ID                                   
;

SELECT ROWNUMBER() OVER(ORDER BY TBL_ELEM_ID) AS UTPNUM
      ,SUBSTR(TBL_ELEM_ID,1,2)                AS UTP   
 FROM prd.TD1_TBL_DTL                                      
WHERE TBL_ID      = 'T013'                             
  AND ORG_CO_NBR  = '1'                                
  AND ORG_RGN_NBR = '00'                               
  AND SUBSTR(TBL_ELEM_TEXT,43,1) = 'Y'                 
ORDER BY TBL_ELEM_ID                                   
;

select *
  from prd.IS2_ITM_SKU
 where (desc_lng_txt like '%PALLET%'
    or desc_lng_txt like '%DIST %'
    or desc_lng_txt like '%DISPLAYER %')
   and sku_typ_cd in ('01','02','03','04','45','64','68','69')
   and rec_stat_cd between '20' and '60'
  with ur
  ;

select *
  from prd.FT1_FT
 where lvl06_cd in ('068','079','082','085','089','095')
 ; 

 (0002396800309, 791, 705)
 (0002600010308, 791, 014)
 (0007251224185, 797, 016)
 0007630890891, 797, 026

 select *
   from prd.pid_orden
  where cas_upc_no = '0007630890891'
    and src_id = '797'
    and bil_div_no = '026'
    ;

 select bil_div_no, cas_upc_no, cat_id, src_id, div_cas_stu_cd, qps_scn_cd
   from prd.pid_orden
  where cas_upc_no = '0007630890891'
    and src_id = '797'
    and bil_div_no = '026'
    ;


select count(*)
  from prd.pid_orden
 where src_id in ('791','792','794','797')
   --and qps_scn_cd not in (' ', 'S', 'N')
   and qps_scn_cd = 'X'
   ;

 select src_id, bil_div_no, cat_id, count(*)
   from prd.pid_orden
  where src_id in ('791','792','794','797')
    and div_cas_stu_cd = 'A'
    --and qps_scn_cd = 'S'
  group by src_id, bil_div_no, cat_id
  order by src_id, bil_div_no, cat_id
    ;

 select *
   from prd.pid_orden
  where src_id in ('792','794')
    and div_inf_cd = 'FMWR'
    ;

select *
  from prd.TD1_TBL_DTL
 where tbl_id = 'K002'
 ;

select substr(tbl_elem_id,1,3)   as srcid
      ,substr(tbl_elem_id,4,3)   as divcd
      ,case substr(tbl_elem_id,7,1)
       when 'A' then
         'ALOC'
       when 'R' then
         'FMWR'
       when 'W' then
         space(4)
       end                       as flowcd
      ,substr(tbl_elem_text,1,2) as id
  from prd.td1_tbl_dtl
 where tbl_id      = 'K002'
   and org_co_nbr  = '1'
   and org_rgn_nbr = '00'
   ;

 select cat_id, count(*)
   from prd.pid_orden
  where src_id = '797'
    and bil_div_no = '701'
  group by cat_id
    --and cat_id = '93'
    ;

select is2.sku_nbr
  from  prd.IS2_ITM_SKU is2
       ,prd.VA1_VNDR_ART va1
 where not exists (
       select 1 
         from prd.SL4_SKU_LOC sl4
        where sl4.sku_nbr = is2.sku_nbr
          and loc_nbr > 999
       )
   and is2.rec_stat_cd = '30'
   and is2.sku_typ_cd = '01'
   and va1.sku_nbr = is2.sku_nbr
   and va1.bas_arl_fl = 'B'
   and va1.art_nbr_id_cd = 'UA'
 fetch first 10 rows only
  with ur;
 ;

 select
   from PIE_PID_INT_ERRS
   ;
