--select cas_upc_no, eas_cd, eas_tag_pdt_pn, eas_eff_dt
SELECT *
  from PRD.pid_pdtca
 where cas_upc_no = '0400040089447'
-- where fam_dpt_cd > ''
-- where CAS_UPC_NO     = '6604441835037'
--where kpc_upc_no > ' '
--  where cas_upc_no > '0010000000000'
-- where cas_dcn_dt >= current date + 360 days
--where cas_shp_fl != ' '
order by cas_upc_no
fetch first 1000 rows only
;

select cas_upc_no, cas_dsc_tx
  from accp.pid_pdtca
 where lfo_grp_cls_id = 07
   and lfo_grp_sub_id = 180
order by cas_upc_no
fetch first 1000 rows only
;

select eas_cd
      ,count(*) as cnt
  from prd.pid_pdtca
group by eas_cd
order by eas_cd
;

select substr(whsca.itm_no,1,8) as sku
      ,pdtca.gtin_cnv_upc_no    as cas_gtin
  from accp.pid_pdtca pdtca
      ,accp.pid_whsca whsca
 where pdtca.cas_upc_no = whsca.cas_upc_no
   and pdtca.gtin_cnv_upc_no > space(13)
   and whsca.src_id     = '791'
;

SELECT pdtca.*
  from PRD.pid_pdtca pdtca
      ,prd.pid_whsca whsca
 where pdtca.cas_upc_no = whsca.cas_upc_no
   and whsca.src_id in ('010','086')
fetch first 1000 rows only
;