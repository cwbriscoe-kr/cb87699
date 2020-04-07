with whs as ( 
 select substr(tbl_elem_id,1,5)   as mag_whse 
       ,substr(tbl_elem_text,1,3) as pid_whse
   from prd.td1_tbl_dtl 
  where tbl_id            = 'K006' 
), 

skutype as ( 
 select substr(tbl_elem_id,1,2) as code
   from prd.td1_tbl_dtl
  where tbl_id = 'F026' 
    and substr(tbl_elem_text,26,1) = 'Y' 
), 

magbas as (
  select is2.sku_nbr        as sku
        ,sv1.mstr_art_nbr   as magcas
        ,va1.art_nbr        as magbas
        ,CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),1,1)
         ||SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),3,1)     
         ||SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),2,1)     
         ||SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),4,10),13) as pidcas
        ,CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM(va1.art_nbr),14)),1,1)
         ||SUBSTR(DIGITS(DECIMAL(RTRIM(va1.art_nbr),14)),3,1)     
         ||SUBSTR(DIGITS(DECIMAL(RTRIM(va1.art_nbr),14)),2,1)     
         ||SUBSTR(DIGITS(DECIMAL(RTRIM(va1.art_nbr),14)),4,10),13) as pidbas
        ,sv1.mstr_pack_qty as case_pack
    from prd.is2_itm_sku      is2
        ,prd.va1_vndr_art     va1
        ,prd.sv1_sku_vndr_dtl sv1
        ,prd.sl4_sku_loc      sl4
   where va1.sku_nbr            = is2.sku_nbr
     and va1.vndr_nbr           = is2.vndr_nbr
     and va1.sku_nbr            = sv1.sku_nbr
     and va1.vndr_nbr           = sv1.vndr_nbr
     and sl4.sku_nbr            = va1.sku_nbr
     and sl4.loc_nbr            = '00065'
     and sl4.rec_stat_cd        = '01'
     and sv1.prmy_altn_vndr_ind = 'P'
     and is2.rec_stat_cd   in ('20', '30')
     and is2.sku_typ_cd    in ('01','02','03','04','55')
     and va1.bas_arl_fl     = 'B'
     and length(ltrim(rtrim(sv1.mstr_art_nbr))) > 0
     and length(ltrim(rtrim(va1.art_nbr))) > 0
--group by is2.vndr_nbr, va1.art_nbr, is2.sku_nbr, is2.rec_stat_cd
)

select *
  from magbas
--fetch first 10000 rows only
;