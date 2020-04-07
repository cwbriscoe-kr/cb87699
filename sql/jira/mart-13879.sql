with validskus as (
select sl4.sku_nbr as sku
  from prd.SL4_SKU_LOC  sl4
      ,prd.VD1_VNDR_DTL vd1
 where sl4.loc_nbr            = '00300'
   and sl4.rec_stat_cd        = '01'
   and sl4.prmy_srce_nbr      = vd1.vndr_nbr
   and vd1.vnd_one_time_vend  = 'V'
   and not exists (
       select 1
         from prd.SL4_SKU_LOC s
        where s.loc_nbr      != '00300'
          and s.sku_nbr       = sl4.sku_nbr
          and s.prmy_srce_nbr = sl4.prmy_srce_nbr
        fetch first 1 row only
       )
), currtemps as (
select chng_nbr
      ,sku_nbr
  from prd.PP1_MDSE_PRC_PND
      ,validskus
 where sku_nbr       = validskus.sku
   and loc_nbr       = '00300'
   and perm_temp_ind = 'T'
), modeltemps as ( 
select p.chng_nbr
      ,p.sku_nbr
      ,c.chng_nbr as missing
  from validskus
      ,prd.PP1_MDSE_PRC_PND p
  left outer join currtemps c on (p.chng_nbr = c.chng_nbr and p.sku_nbr = c.sku_nbr)
 where p.sku_nbr       = validskus.sku
   and p.loc_nbr       = '00035'
   and p.perm_temp_ind = 'T'
   and p.stat_ind in ('Z','L','A')
   and p.prc_typ_cd in ('10','11','12','13','14','15','55','60','61','62','63','80','82','89')
   and c.chng_nbr is null
), missing as (
select *
  from modeltemps m
 where not exists (
       select 1
         from prd.SO1_PRC_SKU_OVR s
        where s.chng_nbr  = m.chng_nbr
          and s.sku_nbr   = m.sku_nbr
          and s.loc_nbr   = '00300'
          and s.xcld_flg  = 'X'
        fetch first 1 row only
       )
   and exists (
       select 1
         from prd.SO1_PRC_SKU_OVR s
             ,prd.GM2_PRC_GRP_MDL g
        where s.chng_nbr  = m.chng_nbr
          and s.sku_nbr   = m.sku_nbr
          and s.loc_nbr   = space(5)
          and s.xcld_flg  = 'I'
          and g.loc_nbr   = '00300'
          and g.prc_grp_id = s.prc_grp_id
        fetch first 1 row only
      )
)
select pp1.sku_nbr
      ,'00300' as loc_nbr
      ,max(pp1.eff_fr_dt, current date + 1 day) as eff_fr_dt
      ,cd4.eff_to_dt
      ,pp1.chng_nbr
      ,pp1.perm_temp_ind
      ,pp1.prc_typ_cd
      ,pp1.adj_prc_amt
      ,pp1.adj_prc_pct
      ,pp1.fix_unt_prc_amt
      ,pp1.n_for_qty
      ,pp1.n_for_prc_amt
      ,pp1.prc_mthd_cd
      ,pp1.prty_cd
      ,pp1.pos_ind
      ,'A' as stat_ind
      ,current date as rec_crt_dt
      ,current timestamp as rec_alt_ts
      ,'300AUDIT' as oper_id
      ,pp1.grp_ind
  from prd.PP1_MDSE_PRC_PND pp1
      ,prd.CD4_CHNG_DFLT cd4
      ,missing
 where pp1.chng_nbr = missing.chng_nbr
   and pp1.sku_nbr  = missing.sku_nbr
   and pp1.loc_nbr  = '00035'
   and pp1.chng_nbr = cd4.chng_nbr
 order by pp1.chng_nbr, pp1.sku_nbr
  with ur
  ;

select *
  from prd.PP1_MDSE_PRC_PND
 where chng_nbr = 634971
 ;

select *
  from prd.CD4_CHNG_DFLT
  ;

select *
  from prd.CS7_PRC_CHNG_STRUC
  ;

select *
  from prd.SO1_PRC_SKU_OVR
 where chng_nbr = 2069571
  ;
select *
  from prd.GM2_PRC_GRP_MDL
  ;