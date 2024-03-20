select *
  from prd.or1_mcs_org_rqst
  with UR;
  
select *
  from prd.or2_org_rgn oor
  with UR;
  
select *
  from prd.or3_org_rgn oor
  with UR;
  
select *
  from prd.dl2_org_dept_loc dodl
  with UR;
  
select *
  from prd.ol1_org_loc ool
 where org_rgn_nbr = '92'
  with ur;

select *
  from prd.sa3_skc_sle sss 
  with ur;
  
select SUBSTR(CHAR((DECIMAL(RTRIM(va1.art_nbr),14))),2,13) as upc
      ,art_nbr 
  from prd.va1_vndr_art va1
  with ur;   --'0000071666537'
  
  
select *
  from prd.ft1_ft
 where lvl08_cd = 987
   and lvl_nbr = 8
   and eff_to_dt > current date
  with ur;

select *
  from prd.ld1_ft_loc_dflt lfld 
 where lvl01_cd = 1
   and lvl02_cd = 1
   and lvl03_cd = 5
   and lvl04_cd = 9
   and lvl05_cd = 915
   and lvl06_cd = 95
   and lvl07_cd = 590
   and lvl08_cd = 987
  with ur;
 
select fi1.ft_lvl06_cd, count(*)
  from prd.is2_itm_sku is2
      ,prd.fi1_ft_itm fi1
 where fi1.itm_nbr = is2.itm_nbr
   and fi1.rec_stat_cd = '01'
   and is2.rec_crt_dt between '2023-01-01' and '2023-12-31'
   and is2.sku_typ_cd not in ('DS','08','10','25','30','35','40')
 group by fi1.ft_lvl06_cd 
 ;
 
select count(*)
  from prd.rs5_rpln_skl rs5
 where skl_grp_cd like '50%'
  with ur
  ;
  
select skl_grp_cd, count(*) as cnt
  from prd.rs5_rpln_skl rs5
 where skl_grp_cd like '50%'
 group by skl_grp_cd
 order by cnt desc
  with ur
  ;

select *
  from prd.al9_audit_log
 where rec_alt_ts >= '2024-02-06-00.29.34.442977'
   --and txn_type = 8021
  with ur
;

select *
  from prd.ppq_pid_proc_que
 with ur;

select *
  from prd.nt3_skc_net_tfr
  with ur;

select *
  from prd.spl_sku_pg_loc
 where loc_nbr like '00%'
  with ur;

select *
  from prd.spg_sku_prod_grp
  with ur;

select *
  from prd.th2_tbl_hdr
 where tbl_desc like '%SMITH%'
  with ur;

select *
  from prd.tss_sched_task
  with ur;

select *
  from prd.tsk_task
  with ur;

select *
  from prd.ol2_org_loc
 where org_co_id = '91'
   and org_rgn_id = '21'
order by org_rgn_id, loc_id
  with ur;

select oa1.*
  from prd.ol2_org_loc ol2
      ,prd.oa1_org_addr oa1
 where 1=1
   and ol2.addr_key_nbr = oa1.addr_id
   and ol2.loc_id like '50%'
  with ur;

select skl_grp_cd
      ,count(*) as item_count
  from prd.rs5_rpln_skl
 where skl_grp_cd like '21%'
 group by skl_grp_cd
 order by count(*) desc
  with ur;

select *
  from accp.td1_tbl_dtl
 where tbl_id = 'K015'
  with ur;

select *
  from prd.sl4_sku_loc
 where loc_nbr like '50%'
   and rec_stat_cd = '01'
  with ur;

select *
  from prd.sla_sku_loc_auth
  with ur;

select rec_stat_cd, is2.*
  from prd.is2_itm_sku is2
 where sku_nbr = '30714717'
  with ur;

select rec_stat_cd, sl4.*
  from prd.sl4_sku_loc sl4
 where sku_nbr = '30714717'
  -- and rec_stat_cd = '01'
 order by loc_nbr
  with ur;

SELECT DISTINCT SL4.SKU_NBR
  FROM prd.SL4_SKU_LOC SL4
 WHERE SL4.LOC_NBR     > '00999'
   AND SL4.REC_STAT_CD < '70'
   and sl4.sku_nbr = '30714717'
   AND NOT EXISTS
      (SELECT 'A'
         FROM prd.SL4_SKU_LOC SL41
        WHERE SL41.SKU_NBR     = SL4.SKU_NBR
          AND SL41.LOC_NBR     < '01000'
          AND SL41.REC_STAT_CD < '69'
          and sl41.loc_nbr != '00461'
       )
 WITH UR;

select *
  from prd.va1_vndr_art va1
 where bas_arl_fl = 'B'
  with ur;

select *
  from prd.moh_mstr_ord_hdr
 where loc_nbr like '50%'
 order by task_nbr
  with ur;