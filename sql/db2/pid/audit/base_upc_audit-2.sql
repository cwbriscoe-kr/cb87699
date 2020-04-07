select substr(itm_no,1,8)  as sku
      ,case
         when txf_cas_upc_no > ' ' then txf_cas_upc_no
         else cas_upc_no
       end                 as casupc
      ,case
         when txf_con_upc_no > ' ' then txf_con_upc_no
         else con_upc_no
       end                 as basupc
      ,cas_pak_qy          as case_pack
      ,ord_mul_qy          as ord_mult
  from prd.pid_whsca
where src_id = '791'
--where cas_upc_no = '0605356904897'
--  and bil_stu_cd = '01'
--fetch first 1000 rows only
;