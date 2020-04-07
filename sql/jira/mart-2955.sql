with skutyp as (
select substr(tbl_elem_id,1,2) as code
from prd.td1_tbl_dtl 
where tbl_id = 'F026'
and org_co_nbr = '1'
and org_rgn_nbr = '00'
and substr(tbl_elem_text,26,1) = 'Y'
), rpt as (
select fi1.ft_lvl07_cd as byr_id
,ft1.desc_lng_txt as byr_nm
,sv1.vndr_nbr as vndr_id
,vd1.vndr_nm as vndr_nm
,fi1.ft_lvl04_cd as div_id
,fi1.ft_lvl06_cd as dpt_id
,fi1.ft_lvl08_cd as cls_id
,fi1.ft_lvl09_cd as scl_id
,is2.sku_nbr as sku_nbr
,va1.art_nbr as bas_upc
,sv1.mstr_art_nbr as cas_upc
,is2.desc_lng_txt as sku_desc
from prd.IS2_ITM_SKU is2
,prd.SV1_SKU_VNDR_DTL sv1
,prd.VA1_VNDR_ART va1
,prd.VD1_VNDR_DTL vd1
,prd.FI1_FT_ITM fi1
--,prd.SPG_SKU_PROD_GRP spg
,prd.FT1_FT ft1
,skutyp
where is2.itm_nbr = fi1.itm_nbr
and is2.rec_stat_cd in ('10','20','30')
and is2.sku_typ_cd = skutyp.code
and fi1.eff_fr_dt <= current date
and fi1.eff_to_dt > current date
and fi1.rec_stat_cd = '01'
and ft1.lvl01_cd = fi1.ft_lvl01_cd
and ft1.lvl02_cd = fi1.ft_lvl02_cd
and ft1.lvl03_cd = fi1.ft_lvl03_cd
and ft1.lvl04_cd = fi1.ft_lvl04_cd
and ft1.lvl05_cd = fi1.ft_lvl05_cd
and ft1.lvl06_cd = fi1.ft_lvl06_cd
and ft1.lvl07_cd = fi1.ft_lvl07_cd
and ft1.lvl_nbr = 7
and ft1.rec_stat_cd = '01'
and sv1.sku_nbr = is2.sku_nbr
and sv1.vndr_nbr = vd1.vndr_nbr
and sv1.prmy_altn_vndr_ind = 'P'
and sv1.ctry_orig_cd = 'XY'
and va1.sku_nbr = sv1.sku_nbr
and va1.bas_arl_fl = 'B'
--and spg.sku_nbr = va1.sku_nbr
--and spg.prod_grp_seq_nbr not in (0,99999)
--and is2.rms_cd = 'Y'
)
--select count from rpt;
select *
from rpt
order by byr_id, vndr_id, cls_id, scl_id, sku_nbr
 with ur
;

