with skus as (
select distinct sku_nbr
 from prd.rs5_rpln_skl
where skl_grp_cd like '50%'
)
select skus.sku_nbr
      ,(select count(*)
          from prd.rs5_rpln_skl rs5
         where rs5.sku_nbr = skus.sku_nbr
           and skl_grp_cd like '50%') as qfc_store_count
      ,is2.desc_lng_txt 
  from skus 
      ,prd.is2_itm_sku is2
 where skus.sku_nbr = is2.sku_nbr
  with ur;
  

with locs as (
select distinct skl_grp_cd as loc_nbr
  from prd.rs5_rpln_skl
 where skl_grp_cd like '50%'
)
select locs.loc_nbr
      ,count(*) as item_count
  from locs
      ,prd.rs5_rpln_skl rs5
 where locs.loc_nbr = rs5.skl_grp_cd 
 group by locs.loc_nbr
 order by count(*)
  with ur;
  

select count(*)
  from prd.rs5_rpln_skl rrs 
 where skl_grp_cd like '50%'
 ;
 
select mdse_flow_cd as flow_code
      ,count(*) as sku_count
  from prd.sl4_sku_loc sl4
 where loc_nbr like '50%'
   and rec_stat_cd = '01'
 group by mdse_flow_cd 
 order by count(*) desc
  with ur;
  
select loc_nbr
      ,mdse_flow_cd as flow_code
      ,count(*) as sku_count
  from prd.sl4_sku_loc sl4
 where loc_nbr like '50%'
   and rec_stat_cd = '01'
 group by loc_nbr, mdse_flow_cd 
 order by loc_nbr, count(*) desc
  with ur;
  
select mdse_flow_cd as flow_code
      ,count(*) as sku_count
  from prd.sl4_sku_loc sl4
      ,prd.ol2_org_loc ol2
      ,prd.is2_itm_sku is2
      ,prd.oh3_skc_oh oh3
      ,prd.oo3_skc_oo oo3
 where sl4.loc_nbr like '50%'
   and sl4.rec_stat_cd = '01'
   and sl4.loc_nbr = ol2.loc_id 
   and sl4.sku_nbr  = is2.sku_nbr 
   and oh3.sku_nbr = is2.dec_sku_nbr 
   and oh3.loc_nbr = ol2.dec_loc_nbr 
   and oo3.sku_nbr = is2.dec_sku_nbr 
   and oo3.loc_nbr = ol2.dec_loc_nbr 
   and oh3.perd_fr_dt = '2023-12-17'
   and oo3.perd_fr_dt = '2023-12-17'
   and is2.rec_stat_cd = '30'
   and (oh3.qty > 0 or oo3.qty > 0)
 group by mdse_flow_cd 
 order by count(*) desc
  with ur;
  
with detail as (
select sl4.loc_nbr 
      ,sl4.mdse_flow_cd as flow_code
      ,coalesce((select max(qty)
                  from prd.oh3_skc_oh oh3 
                  where oh3.sku_nbr = is2.dec_sku_nbr
                    and oh3.loc_nbr = ol2.dec_loc_nbr
                    and oh3.perd_fr_dt = '2023-12-17'),0) as oh3_qty
      ,coalesce((select max(qty) 
                  from prd.oo3_skc_oo oo3
                  where oo3.sku_nbr = is2.dec_sku_nbr
                    and oo3.loc_nbr = ol2.dec_loc_nbr
                    and oo3.perd_fr_dt = '2023-12-17'),0) as oo3_qty
  from prd.sl4_sku_loc sl4
      ,prd.ol2_org_loc ol2
      ,prd.is2_itm_sku is2
 where sl4.loc_nbr like '50%'
   and sl4.rec_stat_cd = '01'
   and sl4.loc_nbr = ol2.loc_id 
   and sl4.sku_nbr  = is2.sku_nbr 
   and is2.rec_stat_cd in ('30','30')
)
select flow_code
      ,count(*) as item_count
  from detail
 where (oh3_qty > 0 or oo3_qty > 0)
group by flow_code
order by count(*) desc
  with ur;
  
select count(*)
  from prd.oh3_skc_oh 
 where perd_fr_dt = '2023-12-17'
   and loc_nbr between 50000 and 60000
   and qty > 0
  with ur; // 81239
  
select count(*)
  from prd.oo3_skc_oo
 where perd_fr_dt = '2023-12-17'
   and loc_nbr between 50000 and 60000
   and qty > 0
  with ur; // 986
  
select *
  from prd.oo3_skc_oo oso 
 where loc_nbr in (50883, 50894, 50972)
  with ur;

select min(perd_fr_dt)
  from prd.sa4_skp_sle sss 
  with ur;
  
