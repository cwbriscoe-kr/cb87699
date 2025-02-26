-- noinspection SqlConstantConditionForFile

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

select *
  from prd.rs8_rpln_srce
 where srce_id = '63421201'
  with ur;

select *
  from accp.ld1_ft_loc_dflt
 where lvl08_cd = 925
   --and lvl04_cd = 8
  with ur;

SELECT *
  FROM accp.FT1_FT
 WHERE LVL04_CD = 9
   AND LVL06_CD = 85
   AND LVL08_CD = 925
   AND LVL_NBR  = 8
   AND EFF_FR_DT < CURRENT DATE
   AND EFF_TO_DT > CURRENT DATE
  WITH UR;

select *
  from accp.ft1_ft
 order by rec_crt_dt desc
  with ur;

SELECT *
FROM accp.FT1_FT
WHERE LVL04_CD = 8
  AND LVL06_CD = 84
  AND LVL08_CD = 925
  AND LVL_NBR  = 8
  AND EFF_TO_DT > CURRENT DATE
WITH UR;

delete
from accp.fd1_ft_dflt
where lvl01_cd = 1
  and lvl02_cd = 1
  and lvl03_cd = 5
  and lvl04_cd = 8
  and lvl05_cd = 825
  and lvl06_cd = 84
  and lvl07_cd = 710
  and lvl08_cd = 925
;

delete
from accp.ld1_ft_loc_dflt
where lvl01_cd = 1
  and lvl02_cd = 1
  and lvl03_cd = 5
  and lvl04_cd = 8
  and lvl05_cd = 825
  and lvl06_cd = 84
  and lvl07_cd = 710
  and lvl08_cd = 925
;

select *
from accp.fd1_ft_dflt
where lvl01_cd = 1
  and lvl02_cd = 1
  and lvl03_cd = 5
  and lvl04_cd = 8
  and lvl05_cd = 825
  and lvl06_cd = 84
  and lvl07_cd = 710
  and lvl08_cd = 925
with ur;

select *
from accp.ld1_ft_loc_dflt
where lvl01_cd = 1
  and lvl02_cd = 1
  and lvl03_cd = 5
  and lvl04_cd = 8
  and lvl05_cd = 825
  and lvl06_cd = 84
  and lvl07_cd = 710
  and lvl08_cd = 925
with ur;

select *
from accp.ld1_ft_loc_dflt
where lvl01_cd = 1
  and lvl02_cd = 1
  and lvl03_cd = 5
  and lvl04_cd = 9
  and lvl05_cd = 910
  and lvl06_cd = 85
  and lvl07_cd = 170
  and lvl08_cd = 925
with ur;

with ft as (
select lvl08_cd
     , count(*) as cnt
  from accp.ft1_ft
 where lvl_nbr = 8
   --and lvl04_cd in (7,8,9)
   and eff_fr_dt < CURRENT DATE
   and eff_to_dt > CURRENT DATE
group by lvl08_cd
having count(*) > 1
)
select ft1.*
  from ft
      ,accp.ft1_ft ft1
 where ft1.lvl08_cd = ft.lvl08_cd
   and eff_fr_dt < current date
   and eff_to_dt > current date
   and lvl_nbr = 8
 order by lvl08_cd
 WITH UR
;

select *
  from accp.ft1_ft
 where lvl_nbr = 8
   and eff_fr_dt < current date
   and eff_to_dt > current date
   and lvl08_cd = 925
  with ur;

select *
  from prd.ld1_ft_loc_dflt
 where lvl04_cd not in (7,8,9)
  with ur;

select *
  from prd.sv1_sku_vndr_dtl
 where case_art_nbr in (
'10051000090543',
'10051000175189',
'10051000075205',
'10011110636703',
'10011110636710',
'10011110905632',
'00011110102294',
'00011110102300'
     )
with ur;


select *
  from accp.ppq_pid_proc_que
  with ur;

select *
  from accp.is2_itm_sku
 where sku_nbr = '00044844'
 with ur;

select *
  from prd.rs5_rpln_skl
  with ur;

select inf_svc_lvl_cd
      ,count(*) as cnt
  from prd.rs5_rpln_skl
 group by inf_svc_lvl_cd
 order by count(*) desc
  with ur;

select *
  from prd.ad3_skc_adj
 where sku_nbr = 21136818
 order by perd_fr_dt desc
  with ur;

select *
  from prd.adz_cskp_adj
  with ur;

select *
  from prd.rs8_rpln_srce
 where srce_id = 10776400
;

select *
  from prd.is2_itm_sku
 where sku_nbr = '29661213'
  with ur;

select *
  from prd.oh3_skc_oh
  with ur;

select is2.rec_stat_cd
      ,count(*) as cnt
  from prd.is2_itm_sku is2
 where is2.rec_stat_chng_dt < current date - 1 year
 group by is2.rec_stat_cd
 order by is2.rec_stat_cd
  with ur;

select count(*) from prd.rs5_rpln_skl with ur;

select *
  from prd.fd1_ft_dflt
 order by rec_alt_ts desc
  with ur;

select *
  from prd.al1_audit_log
 where prgm_id = 'UAC0030'
   and user_id = 'JB37235'
 order by log_dt desc
  with ur;

select min(rec_crt_ts)
  from prd.al1_audit_log
  with ur;

select *
  from accp.fi1_ft_itm
 where itm_nbr = '11027928'
  with ur;

select *
  from accp.fi1_ft_itm
 where oper_id = 'JB37235'
   and rec_crt_dt = '2024-07-30'
  with ur;

select *
  from prd.fi1_ft_itm
 where rec_stat_cd = '09'
  with ur;

with report as (
  select rs5.*, rand() random
    from prd.rs5_rpln_skl rs5
)
select srce_id as vendor
      ,sku_nbr as sku
      ,skl_grp_cd as loc
      ,skl_rpln_mthd_cd as mthd
  from report
 order by random
 fetch first 1000 rows only;

select *
  from prd.ld1_ft_loc_dflt
  with ur;

select *
  from prd.is2_itm_sku
 where rec_stat_cd = '30'
   and sku_typ_cd = '01'
  with ur;

select *
  from prd.dl1_org_dept_loc
 where rec_stat_cd = '01'
  with ur;

select *
  from prd.sl4_sku_loc
  with ur;

select *
  from prd.va1_vndr_art
 where sku_nbr = '32687040'
  with ur;

select *
  from accp.ap1_ac_appl_prf
  with ur;

select *
from accp.ua1_ac_usr_appl
with ur;

select *
  from accp.td1_tbl_dtl
 where tbl_elem_text like 'FRED MEYER%'
  with ur;

select *
from accp.jp1_job_parm
where parm_txt like 'FRED MEYER%'
with ur;

select *
  from prd.rs8_rpln_srce
 where srce_id = '10428300'
  with ur;

select *
  from sv1_sku_vndr_dtl
 where vndr_nbr = '10428300'
  with ur;

select *
from prd.rs8_rpln_srce
where srce_id like '104283%'
with ur;

select *
  from prd.is2_itm_sku
-- where sku_nbr = '01056211'
 where sku_typ_cd = '01'
   and rec_stat_cd = '30'
   and substr(desc_shrt_txt,1,2) = 'OS'
   and substr(desc_shrt_txt,1,3) != 'OSU'
  with ur;

select *
  from prd.fi1_ft_itm
 where itm_nbr = '14609374'
  with ur;

select vndr_id
      ,po_id
      ,arr_dt
      ,arr_dt_to
  from prd.tc2_po_trm_cond
 where vndr_id = '10428300'
  with ur;

select *
  from prd.li2_po_ln_itm
 where po_id = '000034585722'
  with ur;

select *
  from prd.rs5_rpln_skl
 where sku_nbr = '89456217'
  with ur;

select *
  from prd.sl4_sku_loc
 where sku_nbr = '89456217'
  with ur;

select *
  from prd.ft1_ft
 where lvl01_cd = 1
   and lvl02_cd = 1
   and lvl03_cd = 4
   and lvl_nbr = 8
  with ur;

select *
  from prd.li2_po_ln_itm
  with ur;

select *
  from prd.rs8_rpln_srce
 where srce_id = '10776400'
 --where srce_id = '10469000'
  with ur;

select *
  from prd.rs5_rpln_skl
 where srce_id = '10776400'
  with ur;

select *
  from prd.rs5_rpln_skl
 where sku_nbr = '01140149'
   and skl_grp_cd in ('00005','00011','00013','00017','00018')
 order by skl_grp_cd
  with ur;

select *
  from accp.rs5_rpln_skl
 where skl_rpln_mthd_cd = 'I'
 order by sku_nbr desc
  with ur;

select distinct va1.art_nbr_id_cd
  from prd.va1_vndr_art va1
  with ur;

select *
  from prd.pp1_mdse_prc_pnd
  with ur;
  
select *
  from prd.rs5_rpln_skl rrs 
 where rrs.org_id = '99'
  with ur;

select *
  from prd.pm2_mdse_prc_mstr
 where sku_nbr = '12717118'
   and loc_nbr = '00111'
  with ur;


select *
  from prd.va1_vndr_art
 where bas_arl_fl = 'B'
  with ur;

select *
  from prd.pp1_mdse_prc_pnd
 where stat_ind in ('L', 'A')
   and prc_typ_cd in ('07','08','67','68','77','78','65','66','60','61','62','63','89')
  with ur;

select is2.*
  from prd.is2_itm_sku is2
   where not exists (
       select 1
         from prd.va1_vndr_art va1
        where va1.sku_nbr = is2.sku_nbr
          and va1.ld_art_ind = 'L'
 )
;

select *
  from prd.is2_itm_sku
 where sku_nbr = '52969645'
  with ur;

select *
  from prd.va1_vndr_art
 where sku_nbr = '97805717'
  with ur;
