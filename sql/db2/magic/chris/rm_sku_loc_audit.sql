with skutyp as (
  select substr(tbl_elem_id,1,2) as type
  from td1_tbl_dtl
  where tbl_id      = 'F026'
    and org_co_nbr  = '1'
    and org_rgn_nbr = '00'
    and substr(tbl_elem_text,26,1) = 'Y'
), skus as (
  select rs8.srce_id           as vndr_nbr
        ,rs8.srce_rpln_mthd_cd as rpln_mthd
        ,rs8.srce_whse_nbr     as srce_whse
        ,is2.sku_nbr           as sku_nbr
        ,is2.rms_cd            as rms_cd
        ,is2.oper_id           as user_id
        ,is2.rec_alt_ts        as change_ts
    from is2_itm_sku is2
        ,sv1_sku_vndr_dtl sv1
        ,rs8_rpln_srce rs8
        ,skutyp
   where 1 = 1
     and is2.sku_typ_cd = skutyp.type
     and is2.sku_vld_fr_dt <= current date
     and is2.sku_vld_to_dt >= current date
     and is2.rec_stat_cd between '10' and '70'
     and sv1.vndr_nbr = rs8.srce_id
     and sv1.sku_nbr = is2.sku_nbr
     and sv1.rec_stat_cd = '01'
), blocked as (
  select TBL_ELEM_ID as loc_id
    from td1_tbl_dtl
   where tbl_id = 'R006'
), locs as (
  select *
    from sl4_sku_loc sl4
        ,skus
  where sl4.sku_nbr = skus.sku_nbr
    and sl4.rec_stat_cd = '01'
    and sl4.loc_nbr not in (
      select loc_id from blocked
    )
    and sl4.mdse_flow_cd = (
      select case skus.rpln_mthd
             when 'I' then 'RMA'
             when 'D' then 'DC'
             when 'B' then 'DTS'
             when 'S' then 'DTS'
             end as rpln_mthd
        from tt1_truth_tbl
    )
    and sl4.prmy_srce_nbr = (
      select case skus.rpln_mthd
             when 'B' then skus.srce_whse
             when 'S' then skus.srce_whse
             else skus.vndr_nbr
             end as prmy_srce
        from tt1_truth_tbl
    )
    and sl4.prmy_srce_typ_cd = (
      select case skus.rpln_mthd
             when 'B' then 'D'
             when 'S' then 'D'
             else 'V'
             end as prmy_srce_typ
        from tt1_truth_tbl
    )
)
  select count(*)
--select mdse_flow_cd, locs.*
  from locs
  with ur;

