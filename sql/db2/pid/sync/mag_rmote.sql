with skutyp as (
 select tbl_elem_id               as code
   from accp.td1_tbl_dtl
  where tbl_id = 'F026'
    and substr(tbl_elem_text,26,1) = 'Y'
),
upctyp as (
 select tbl_elem_id               as code
   from accp.td1_tbl_dtl
  where tbl_id = 'T013'
    and substr(tbl_elem_text,43,1) = 'Y'
)  
select CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM( 
       SV1.MSTR_ART_NBR),14)),1,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       SV1.MSTR_ART_NBR),14)),3,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       SV1.MSTR_ART_NBR),14)),2,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       SV1.MSTR_ART_NBR),14)),4,10),13)   as cas_upc_no	 
      ,CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM( 
       VA1.ART_NBR),14)),1,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       VA1.ART_NBR),14)),3,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       VA1.ART_NBR),14)),2,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       VA1.ART_NBR),14)),4,10),13)        as con_upc_no
      ,'MAG'                              as sys_id
      ,is2.itm_nbr || space(6)            as itm_no
      ,is2.desc_lng_txt || space(5)       as itm_dsc_tx
      ,case
       when is2.rec_stat_cd < '40' then
         'A'
       else
         'W'
       end                                as stu_cd
      ,digits(decimal(fi1.ft_lvl06_cd,4)) as fam_dpt_cd
      ,digits(decimal(fi1.ft_lvl08_cd,4)) as fam_cls_cd
      ,digits(decimal(fi1.ft_lvl09_cd,4)) as fam_sbc_cd
      ,case is2.sku_typ_cd
       when '55' then
         'Y'
       else
         ' '
       end                                as cas_shp_fl
      ,id1.desc_shrt_txt                  as itm_abb_dsc_tx
      ,decimal(sv1.mstr_pack_qty,5)       as shp_pak_qy
      ,case va1.bas_arl_fl
       when 'B' then
         '1'
       else
         ' '
       end                                as con_typ_cd
      ,coalesce( 
       (select sd3.plu_desc
          from accp.sd3_sd_sku_dtl sd3 
         where sd3.sku_nbr = is2.sku_nbr 
       ),substr(is2.desc_shrt_txt,1,12) 
      )                                   as con_dsc_abb_tx
      ,is2.sku_nbr                        as sku_no
      ,is2.sell_uom                       as siz_uom_cd
  from accp.is2_itm_sku        is2
      ,accp.fi1_ft_itm         fi1
      ,accp.id1_itm_dtl        id1
      ,accp.sv1_sku_vndr_dtl   sv1
      ,accp.va1_vndr_art       va1
      ,skutyp
      ,upctyp
 where is2.rec_stat_cd        between '20' and '60'
   and is2.sku_typ_cd         = skutyp.code
   and is2.sku_nbr            = sv1.sku_nbr
   and is2.vndr_nbr           = sv1.vndr_nbr
   and fi1.itm_nbr            = is2.itm_nbr 
   and fi1.eff_fr_dt         <= current date 
   and fi1.eff_to_dt         > current date
   and fi1.rec_stat_cd        = '01' 
   and id1.itm_nbr            = fi1.itm_nbr
   and sv1.sku_nbr            = va1.sku_nbr
   and sv1.vndr_nbr           = va1.vndr_nbr
   and sv1.prmy_altn_vndr_ind = 'P'
   and va1.art_nbr_id_cd      = upctyp.code
   and length(ltrim(rtrim(sv1.mstr_art_nbr))) > 0
   and is2.sku_nbr = '04620310'
 order by cas_upc_no, con_upc_no, sys_id
  with ur
 fetch first 1000 rows only
; 


