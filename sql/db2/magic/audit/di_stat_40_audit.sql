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
  from prd.is2_itm_sku is2
      ,prd.fi1_ft_itm fi1
      ,prd.va1_vndr_art va1
      ,stypes
 where is2.rec_stat_cd = '20'
   and is2.rec_crt_dt < current date - 1 year
   and is2.sku_typ_cd = stypes.stype
   and fi1.itm_nbr = is2.itm_nbr
   and fi1.rec_stat_cd = '01'
   and va1.sku_nbr = is2.sku_nbr
   and va1.bas_arl_fl = 'B'
   and not exists (
       select 1
         from prd.oo3_skc_oo oo3
        where oo3.sku_nbr = is2.dec_sku_nbr 
          and oo3.qty > 0.0
    )
   and not exists (
        select 1
          from prd.oh3_skc_oh oh3
         where oh3.sku_nbr = is2.dec_sku_nbr
           and oh3.qty != 0.0
    )
 order by fi1.ft_lvl06_cd
         ,fi1.ft_lvl07_cd 
         ,is2.sku_nbr 
  with ur;