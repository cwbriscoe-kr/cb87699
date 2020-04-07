select *
  FROM accp.IS2_ITM_SKU
 where sku_nbr > '90000000'
   and sku_typ_cd = '01'
   and rec_stat_cd = '30'
   and art_nbr_id_cd = 'CA'
 order by sku_nbr
   ;

select mfg_upc_no, mfr_gtin_cnv_dt
  from accp.pid_mfgid
 where mfg_upc_no > '04000000'
 order by mfg_upc_no
;

SELECT *
  FROM ACCP.SV1_SKU_VNDR_DTL
 WHERE PRMY_ALTN_VNDR_IND = 'P'
   AND MSTR_ART_TYP_CD = 'CK'
;