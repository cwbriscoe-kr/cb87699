with PARMS as (
select '225' as byrid
  from prd.TT1_TRUTH_TBL
), THISDAY as (
select dayofweek(current date) daynum
  from prd.TT1_TRUTH_TBL
), THISSUN AS (
select case daynum
       when 0 then
         current date
       else
          current date - (daynum -1) days
       end as dt
  from thisday
), dates as (
select dt as oh3date
      ,dt - 21 days as ad3date
  from THISSUN
), base as (
select rs8.srce_ownr_id      as byr_nbr
      ,rs8.srce_id           as src_id
      ,rs8.srce_rpln_mthd_cd as rpln_mthd
      ,rs5.sku_nbr           as sku_nbr
      ,rs5.skl_grp_cd        as loc_nbr
      ,coalesce(oh3.qty,0)   as oh_qty
      ,is2.dec_sku_nbr       as dec_sku_nbr
      ,ol2.dec_loc_nbr       as dec_loc_nbr
  from dates
       inner join parms on 1 = 1
       inner join prd.RS8_RPLN_SRCE rs8 on 1 = 1
       inner join prd.RS6_RPLN_SKU rs6 on rs6.srce_id = rs8.srce_id and rs6.srce_typ_cd = rs8.srce_typ_cd
       inner join prd.RS5_RPLN_SKL rs5 on rs5.srce_id = rs6.srce_id and rs5.srce_typ_cd = rs6.srce_typ_cd and rs5.sku_nbr = rs6.sku_nbr
       inner join prd.IS2_ITM_SKU is2 on is2.sku_nbr = rs5.sku_nbr
       inner join prd.OL2_ORG_LOC ol2 on ol2.loc_id = rs5.skl_grp_cd
       left outer join prd.OH3_SKC_OH oh3 on oh3.sku_nbr = is2.dec_sku_nbr and oh3.loc_nbr = ol2.dec_loc_nbr and oh3.perd_fr_dt = dates.oh3date
 where rs8.srce_rpln_mthd_cd in ('I','B','S')
   and is2.rec_stat_cd = '30'
   and ol2.loc_opn_dt < current date
   and rs5.inf_new_ddu_ind != 'M'
   and rs8.srce_ownr_id = parms.byrid
), vndrskux as (
  select src_id
        ,sku_nbr
    from base
   group by src_id, sku_nbr
), vndrsku as (
select src_id
      ,count(*) as cnt
  from vndrskux
 group by src_id
), INSTK as (
select byr_nbr
      ,src_id
      ,rpln_mthd
      ,loc_nbr
      ,dec_loc_nbr
      ,min(sku_nbr) as min_sku
      ,cast(count(*) as float) as cnt
  from base
 where oh_qty > 0
 group by byr_nbr, src_id, rpln_mthd, loc_nbr, dec_loc_nbr
), OOSTK as (
select byr_nbr
      ,src_id
      ,rpln_mthd
      ,loc_nbr
      ,dec_loc_nbr
      ,min(sku_nbr) as min_sku
      ,cast(count(*) as float) as cnt
  from base
 where oh_qty <= 0
 group by byr_nbr, src_id, rpln_mthd, loc_nbr, dec_loc_nbr
)
, raw as (
select oostk.byr_nbr
      ,oostk.src_id
      ,oostk.rpln_mthd
      ,oostk.min_sku
      ,coalesce(instk.cnt,0) * 100.0 / (coalesce(instk.cnt,0) + oostk.cnt) as instk_pct
      ,oostk.loc_nbr
      ,oostk.dec_loc_nbr
      ,oostk.cnt
  from oostk
       left outer join instk 
         on instk.src_id  = oostk.src_id
        and instk.loc_nbr = oostk.loc_nbr
 union
select instk.byr_nbr
      ,instk.src_id
      ,instk.rpln_mthd
      ,instk.min_sku
      ,cast(100.0 as float) as instk_pct
      ,instk.loc_nbr
      ,instk.dec_loc_nbr
      ,0 as cnt
  from instk
       left outer join oostk 
         on oostk.src_id  = instk.src_id
        and oostk.loc_nbr = instk.loc_nbr
 where oostk.loc_nbr is null
), pretty as (
select raw.byr_nbr
      ,raw.src_id
      ,vd1.vndr_nm     as src_nm
      ,vndrsku.cnt     as sku_cnt
      ,vd1.ord_prs_days + vd1.trnst_days as lead_tm
      ,fi1.ft_lvl08_cd as cls_id
      ,fi1.ft_lvl09_cd as scl_id
      ,case raw.rpln_mthd
       when 'I' then
         'VTS'
       else
         'DTS'
       end as rpln_mthd
      ,raw.loc_nbr
      ,raw.instk_pct
      ,raw.cnt
      ,coalesce((
       select sum(qty)
         from prd.RS6_RPLN_SKU rs6
             ,prd.IS2_ITM_SKU  is2
             ,prd.AD3_SKC_ADJ  ad3
             ,dates
        where rs6.srce_id      = raw.src_id
          and rs6.sku_rpln_mthd_cd = raw.rpln_mthd
          and is2.sku_nbr      = rs6.sku_nbr
          and ad3.sku_nbr      = is2.dec_sku_nbr
          and ad3.loc_nbr      = raw.dec_loc_nbr
          and ad3.perd_fr_dt  >= dates.ad3date
          and ad3.adj_reas_cd in ('36', '38', '40', '46', '50', '51')
       ),0) as adj_qty
  from raw
       inner join vndrsku on vndrsku.src_id = raw.src_id
       inner join prd.VD1_VNDR_DTL vd1 on vd1.vndr_nbr = raw.src_id
       inner join prd.IS2_ITM_SKU is2 on is2.sku_nbr = raw.min_sku
       inner join prd.FI1_FT_ITM fi1 on is2.itm_nbr = fi1.itm_nbr
 where fi1.rec_stat_cd = '01'
)
select *
  from pretty
 order by byr_nbr, src_id, instk_pct, cnt desc, loc_nbr
  with ur
 ;
