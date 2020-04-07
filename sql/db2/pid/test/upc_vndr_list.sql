select sv1.mstr_art_nbr as mupc
      ,vd1.vndr_nm      as vndr_nm
  from prd.sv1_sku_vndr_dtl sv1
      ,prd.vd1_vndr_dtl     vd1
 where sv1.vndr_nbr = vd1.vndr_nbr
   and sv1.mstr_art_nbr not like '400%'
   and sv1.mstr_art_nbr not like '04%'
   and vd1.vndr_nm      not like 'DUMMY%'
fetch first 1000 rows only
;