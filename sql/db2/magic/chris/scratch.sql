select *
  from accp.or1_mcs_org_rqst
  with UR;
  
select *
  from accp.or2_org_rgn oor
  with UR;
  
select *
  from accp.or3_org_rgn oor 
  with UR;
  
select *
  from ACCP.dl2_org_dept_loc dodl 
  with UR;
  
select *
  from accp.ol1_org_loc ool 
 where org_rgn_nbr = '92'
  with ur;

select *
  from prd.sa3_skc_sle sss 
  with ur;
  
select SUBSTR(CHAR((DECIMAL(RTRIM(va1.art_nbr),14))),2,13) as upc
      ,art_nbr 
  from prd.va1_vndr_art va1
  with ur;   '0000071666537'
  
  
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