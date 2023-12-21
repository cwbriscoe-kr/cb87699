with detail as (
select sl4.sku_nbr 
      ,sl4.loc_nbr 
      ,sl4.mdse_flow_cd as flow_code
      ,coalesce((select sum(qty)
                  from prd.oh3_skc_oh oh3 
                  where oh3.sku_nbr = is2.dec_sku_nbr
                    and oh3.loc_nbr = ol2.dec_loc_nbr
                    and oh3.perd_fr_dt = '2023-12-17'),0) as oh3_qty
      ,coalesce((select sum(qty) 
                  from prd.oo3_skc_oo oo3
                  where oo3.sku_nbr = is2.dec_sku_nbr
                    and oo3.loc_nbr = ol2.dec_loc_nbr
                    and oo3.perd_fr_dt = '2023-12-17'),0) as oo3_qty
      ,coalesce((select sum(qty) 
                  from prd.sa3_skc_sle sa3
                  where sa3.sku_nbr = is2.dec_sku_nbr
                    and sa3.loc_nbr = ol2.dec_loc_nbr
                    and sa3.perd_fr_dt >= '2023-01-01'),0) as sa3_qty
      ,coalesce((select sum(rtl_amt) 
                  from prd.sa3_skc_sle sa3
                  where sa3.sku_nbr = is2.dec_sku_nbr
                    and sa3.loc_nbr = ol2.dec_loc_nbr
                    and sa3.perd_fr_dt >= '2023-01-01'),0) as sa3_amt
      ,coalesce((select 'YES'
                   from prd.tt1_truth_tbl
                 where exists (
                select 1
                  from prd.oh3_skc_oh oh3 
                  where oh3.sku_nbr = is2.dec_sku_nbr
                    and oh3.loc_nbr = ol2.dec_loc_nbr
                    and oh3.perd_fr_dt >= '2023-01-01'
                    and qty > 0)),'NO') as oh3_qty_x
      ,coalesce((select 'YES'
                   from prd.tt1_truth_tbl
                 where exists (
                select 1
                  from prd.oo3_skc_oo oo3 
                  where oo3.sku_nbr = is2.dec_sku_nbr
                    and oo3.loc_nbr = ol2.dec_loc_nbr
                    and oo3.perd_fr_dt >= '2023-01-01'
                    and qty > 0)),'NO') as oo3_qty_x
  from prd.sl4_sku_loc sl4
      ,prd.ol2_org_loc ol2
      ,prd.is2_itm_sku is2
 where sl4.loc_nbr like '50%'
   and sl4.rec_stat_cd = '01'
   and sl4.loc_nbr = ol2.loc_id 
   and sl4.sku_nbr  = is2.sku_nbr 
   and sku_typ_cd not in ('DS','08','10','25','30','35','40')
)
select detail.loc_nbr
      ,detail.sku_nbr
      ,detail.flow_code
      ,detail.oh3_qty as on_hand_qty
      ,detail.oo3_qty as on_order_qty
      ,detail.sa3_qty as sales_qty_ytd
      ,detail.sa3_amt as sales_amt_ytd
      ,detail.oh3_qty_x as had_oh_ytd
      ,detail.oo3_qty_x as had_oo_ytd
      ,is2.desc_lng_txt as description
      ,is2.rec_stat_cd as sku_status
      ,is2.sku_typ_cd as sku_type
  from detail 
      ,prd.is2_itm_sku is2
 where detail.sku_nbr =  is2.sku_nbr
 order by loc_nbr, sku_nbr
  with ur;