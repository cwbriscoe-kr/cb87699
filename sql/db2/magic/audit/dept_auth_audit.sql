with stypes as (
    select substr(td1.tbl_elem_id,1,2) as stype
      from prd.td1_tbl_dtl td1
     where td1.tbl_id      = 'F026'
       and td1.org_co_nbr  = '1'
       and td1.org_rgn_nbr = '00'
       and substr(td1.tbl_elem_text,26,1) = 'Y'
)
select fi1.ft_lvl06_cd as dept
      ,fi1.ft_lvl07_cd as buyr
      ,is2.sku_nbr as sku
      ,va1.art_nbr as bas_upc
      ,is2.desc_lng_txt as desc
      ,is2.rec_crt_dt as created
      ,fi1.ft_lvl08_cd as cls
      ,fi1.ft_lvl09_cd as scls
      ,is2.sku_typ_cd as stype
      ,is2.rec_stat_cd as sku_sts
      ,sl4.loc_nbr as loc
  from prd.is2_itm_sku is2
      ,prd.fi1_ft_itm fi1
      ,prd.va1_vndr_art va1
      ,prd.sl4_sku_loc sl4
      ,stypes
 where is2.rec_stat_cd in ('20','30')
   and is2.sku_typ_cd = stypes.stype
   and fi1.itm_nbr = is2.itm_nbr
   and fi1.rec_stat_cd = '01'
   and va1.sku_nbr = is2.sku_nbr
   and va1.bas_arl_fl = 'B'
   and fi1.ft_lvl09_cd != 9
   and sl4.sku_nbr = is2.sku_nbr
   and sl4.rec_stat_cd = '01'
   and not exists (
       select 1
         from prd.dl1_org_dept_loc dl1
        where dl1.org_co_nbr = '1'
          and dl1.dept_nbr = '00' || fi1.ft_lvl06_cd
          and dl1.loc_nbr = sl4.loc_nbr
          and dl1.rec_stat_cd = '01'
   )
 fetch first 1000 rows only
 --order by fi1.ft_lvl06_cd
 --        ,fi1.ft_lvl07_cd
 --        ,is2.sku_nbr
  with ur;