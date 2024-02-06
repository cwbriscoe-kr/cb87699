--qfc e3 detail top 8 stores
with detail as (
select sl4.sku_nbr 
      ,sl4.loc_nbr 
      ,sl4.mdse_flow_cd as flow_code
      ,coalesce((select sum(qty)
                  from prd.oh3_skc_oh oh3 
                  where oh3.sku_nbr = is2.dec_sku_nbr
                    and oh3.loc_nbr = ol2.dec_loc_nbr
                    and oh3.perd_fr_dt = '2024-01-28'),0) as oh3_qty
      ,coalesce((select sum(qty) 
                  from prd.oo3_skc_oo oo3
                  where oo3.sku_nbr = is2.dec_sku_nbr
                    and oo3.loc_nbr = ol2.dec_loc_nbr
                    and oo3.perd_fr_dt = '2024-01-28'),0) as oo3_qty
      ,coalesce((select sum(qty) 
                  from prd.sa3_skc_sle sa3
                  where sa3.sku_nbr = is2.dec_sku_nbr
                    and sa3.loc_nbr = ol2.dec_loc_nbr
                    and sa3.perd_fr_dt >= '2023-01-29'),0) as sa3_qty
      ,coalesce((select sum(rtl_amt) 
                  from prd.sa3_skc_sle sa3
                  where sa3.sku_nbr = is2.dec_sku_nbr
                    and sa3.loc_nbr = ol2.dec_loc_nbr
                    and sa3.perd_fr_dt >= '2023-01-29'),0) as sa3_amt
      ,coalesce((select 'YES'
                   from prd.tt1_truth_tbl
                 where exists (
                select 1
                  from prd.oh3_skc_oh oh3 
                  where oh3.sku_nbr = is2.dec_sku_nbr
                    and oh3.loc_nbr = ol2.dec_loc_nbr
                    and oh3.perd_fr_dt >= '2023-01-29'
                    and qty > 0)),'NO') as oh3_qty_x
      ,coalesce((select 'YES'
                   from prd.tt1_truth_tbl
                 where exists (
                select 1
                  from prd.oo3_skc_oo oo3 
                  where oo3.sku_nbr = is2.dec_sku_nbr
                    and oo3.loc_nbr = ol2.dec_loc_nbr
                    and oo3.perd_fr_dt >= '2023-01-29'
                    and qty > 0)),'NO') as oo3_qty_x
      ,coalesce((select lin_no
                   from prd.k12_pid_whsca whsca
                  where whsca.src_id = '791'
                   and whsca.cas_upc_no =
                       CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),1,1)
                          ||SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),3,1)     
                          ||SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),2,1)     
                          ||SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),4,10),13)
                   ),0) as lin_no_791
      ,coalesce((select lin_no
                   from prd.k12_pid_whsca whsca
                  where whsca.src_id in ('792','794','797')
                   and whsca.cas_upc_no =
                       CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),1,1)
                          ||SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),3,1)     
                          ||SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),2,1)     
                          ||SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),4,10),13)
                   fetch first 1 row only),0) as lin_no_797
  from prd.sl4_sku_loc sl4
      ,prd.ol2_org_loc ol2
      ,prd.is2_itm_sku is2
      ,prd.rs5_rpln_skl rs5
      ,prd.sv1_sku_vndr_dtl sv1
 where sl4.loc_nbr = rs5.skl_grp_cd
   and sl4.sku_nbr = rs5.sku_nbr 
   and sl4.rec_stat_cd = '01'
   and sl4.loc_nbr = ol2.loc_id 
   and sl4.sku_nbr  = is2.sku_nbr 
   and sv1.sku_nbr = is2.sku_nbr 
   and sv1.prmy_altn_vndr_ind = 'P'
   and length(ltrim(rtrim(sv1.mstr_art_nbr))) > 0
   and is2.sku_typ_cd not in ('DS','08','10','25','30','35','40')
   and rs5.skl_grp_cd in ('50808','50894','50101','50837','50863','50878','50879','50887')
)
select detail.loc_nbr
      ,detail.sku_nbr
      ,detail.lin_no_791
      ,detail.lin_no_797
      ,fi1.ft_lvl04_cd as div
      ,fi1.ft_lvl06_cd as dept
      ,fi1.ft_lvl08_cd as cls
      ,fi1.ft_lvl09_cd as scls
      ,detail.flow_code
      ,detail.oh3_qty as on_hand_qty
      ,detail.oo3_qty as on_order_qty
      ,detail.sa3_qty as sales_qty_52wks
      ,detail.sa3_amt as sales_amt_52wks
      ,detail.oh3_qty_x as had_oh_52wks
      ,detail.oo3_qty_x as had_oo_52wks
      ,is2.desc_lng_txt as description
      ,is2.rec_stat_cd as sku_status
      ,is2.sku_typ_cd as sku_type
  from detail 
      ,prd.is2_itm_sku is2
      ,prd.fi1_ft_itm fi1
 where detail.sku_nbr =  is2.sku_nbr
   and fi1.itm_nbr = is2.itm_nbr 
   and fi1.rec_stat_cd = '01'
 order by loc_nbr, sku_nbr
  with ur;