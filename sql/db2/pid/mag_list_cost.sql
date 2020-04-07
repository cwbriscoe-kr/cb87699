with whsdata as (
  select k12.src_id
        ,case k12.src_id
         when '791' then
           '00065'
         else
           '00461'
         end as whs_id
        ,substr(k12.itm_no,1,8) as sku_nbr
        ,lin_no
    from prd.k12_pid_whsca k12
   where k12.src_id in ('791','792','794','797')
),
curcost as (
  select cm1.sku_nbr
        ,whs.src_id
        ,whs.whs_id
        ,whs.lin_no
        ,cm1.eff_fr_dt
        ,(cm1.cost_amt / cm1.cost_unt) as cost    
    from prd.cm1_mdse_cost_mstr cm1
        ,prd.sl4_sku_loc sl4
        ,whsdata whs
   where sl4.sku_nbr = whs.sku_nbr
     and sl4.loc_nbr = whs.whs_id
     and sl4.prmy_srce_nbr = cm1.vndr_nbr
     and cm1.sku_nbr = sl4.sku_nbr
),
avgcost as (
  select cur.*
        ,cast(coalesce((
         select avg_cst_amt
           from prd.ac3_skc_avg_cst ac3
          where ac3.sku_nbr = is2.dec_sku_nbr
            and ac3.loc_nbr = ol2.dec_loc_nbr
           order by eff_fr_dt desc
           fetch first 1 row only
         ),0) as decimal(15,4)) as avgcost
    from prd.is2_itm_sku is2
        ,prd.ol2_org_loc ol2
        ,curcost cur
   where is2.sku_nbr = cur.sku_nbr
     and ol2.loc_id = cur.whs_id
),
pndcost as (
  select cp1.sku_nbr
        ,whs.src_id
        ,whs.whs_id
        ,whs.lin_no
        ,cp1.eff_fr_dt
        ,(cp1.cost_amt / cp1.cost_unt) as cost
        ,cast(0 as decimal(15,4)) as avgcost
    from prd.cp1_mdse_cost_pnd cp1
        ,prd.sl4_sku_loc sl4
        ,whsdata whs
   where cp1.sku_nbr = whs.sku_nbr
     and sl4.sku_nbr = cp1.sku_nbr
     and sl4.loc_nbr = whs.whs_id
     and sl4.prmy_srce_nbr = cp1.vndr_nbr
),
combined as (
  select * from avgcost
   union all
  select * from pndcost
),
report as (
  select com.*
        ,SUBSTR(DIGITS(DECIMAL(TRIM(
         SV1.MSTR_ART_NBR),14)),1,13) AS casupc
        ,SUBSTR(DIGITS(DECIMAL(TRIM(
         va1.ART_NBR),14)),1,13) AS basupc
    from prd.sv1_sku_vndr_dtl sv1
        ,prd.va1_vndr_art va1
        ,combined com
   where sv1.sku_nbr = com.sku_nbr
     and sv1.prmy_altn_vndr_ind = 'P'
     and va1.sku_nbr = sv1.sku_nbr
     and va1.bas_arl_fl = 'B'
)
select * 
  from report
   with ur
;