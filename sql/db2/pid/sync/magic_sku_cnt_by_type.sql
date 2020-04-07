with whs as (
  select substr(tbl_elem_text,1,5) as mag_whse
        ,substr(tbl_elem_id,1,3)   as pid_whse
    from prd.td1_tbl_dtl
   where tbl_id = 'K004'
)

select is2.sku_typ_cd
      ,count(*) as cnt
  from prd.is2_itm_sku      is2
      ,prd.sv1_sku_vndr_dtl sv1
      ,prd.sl4_sku_loc      sl4
      ,prd.va1_vndr_art     va1
      ,whs
 where is2.sku_nbr        = sv1.sku_nbr
   and is2.vndr_nbr       = sv1.vndr_nbr
   and sv1.sku_nbr        = va1.sku_nbr
   and sv1.vndr_nbr       = va1.vndr_nbr
   and va1.sku_nbr        = sl4.sku_nbr
   and sl4.loc_nbr        = whs.mag_whse
   and va1.bas_arl_fl     = 'B'
   and is2.rec_stat_cd   in ('20','30')
   and sl4.rec_stat_cd    = '01'  
group by is2.sku_typ_cd   
order by cnt desc
with ur
;
