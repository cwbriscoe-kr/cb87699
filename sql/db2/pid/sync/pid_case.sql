WITH T295 AS ( 
SELECT SUBSTR(KEY_VLU_CD,1,2)   AS CPT_DPT_CD 
      ,CASE SUBSTR(GNC_TX,27,1) 
       WHEN 'E' THEN 
         'Y' 
       WHEN ' ' THEN 
         'Y' 
       ELSE 
         'N' 
       END                      AS CORP_CNTL_FL 
  FROM accp.PID_TECCODES 
 WHERE TBL_NAM_ID = '0295' 
   AND TBL_OWN_ID = '000' 
) 

,FIXP AS ( 
SELECT '06632748' || '0'                  AS ITM_NO 
 ,COALESCE(CA.CAS_UPC_NO,SPACE(13))       AS CAS_UPC_NO 
 ,COALESCE(CC.CON_UPC_NO,SPACE(13))       AS CON_UPC_NO 
 ,COALESCE(CA.SHP_PAK_QY,0)               AS CAS_PAK_QY 
 ,COALESCE(CA.CAS_DSC_TX,SPACE(30))       AS CAS_DSC_TX 
 ,COALESCE(CA.CAS_LTH_AM,0)               AS CAS_LTH_AM 
 ,COALESCE(CA.CAS_WTH_AM,0)               AS CAS_WTH_AM 
 ,COALESCE(CA.CAS_HGT_AM,0)               AS CAS_HGT_AM 
 ,COALESCE(CA.CAS_GRS_WGT_AM,0)           AS CAS_GRS_WGT_AM
 ,COALESCE(CA.CAS_NET_WGT_AM,0)           AS CAS_NET_WGT_AM
 ,COALESCE(CA.CAS_SIZ_QY,SPACE(8))        AS CAS_SIZ_QY 
 ,COALESCE(CA.CAS_SIZ_CD,SPACE(2))        AS CAS_SIZ_CD 
 ,COALESCE(SC.FAM_DPT_CD,SPACE(4))        AS FAM_DPT_CD 
 ,COALESCE(SC.FAM_CLS_CD,SPACE(4))        AS FAM_CLS_CD 
 ,COALESCE(SC.FAM_SBC_CD,SPACE(4))        AS FAM_SBC_CD 
 ,COALESCE(CA.KLP_KMP_CD,SPACE(1))        AS KLP_KMP_CD 
 ,COALESCE(CO.CON_DSC_ABB_TX_2,SPACE(18)) AS CAS_DSC_ABB_TX
 ,COALESCE(CO.FSA_FL,SPACE(1))            AS FSA_FL 
 ,COALESCE(CA.CAS_SHP_FL,SPACE(1))        AS CAS_SHP_FL 
 ,COALESCE(CA.EAS_CD,SPACE(1))            AS EAS_CD 
 ,COALESCE(CA.EAS_EFF_DT,'0001-01-01')    AS EAS_EFF_DT 
 ,COALESCE(CA.EAS_TAG_PDT_PN,0)           AS EAS_TAG_PDT_PN
 ,COALESCE(CO.EQV_UOM_TYP_CD,SPACE(2))    AS SIZ_UOM_CD 
 ,COALESCE(CA.CPT_DPT_CD,SPACE(2))        AS CPT_DPT_CD 
 ,COALESCE(T295.CORP_CNTL_FL,SPACE(1))    AS CORP_CNTL_FL 
 ,COALESCE((SELECT CON_UPC_NO 
             FROM accp.PID_CASCO CC2 
            WHERE CC2.CAS_UPC_NO = CC.CAS_UPC_NO 
              AND CC2.CON_TYP_CD = '2' 
 ),SPACE(13))                             AS TYP_2_BAS 
 ,CASE 
  WHEN coalesce((
    SELECT 1
      FROM ACCP.PID_ORDEN ORD
     WHERE ORD.CAS_UPC_NO      = '0007148602566'
       AND ORD.BIL_DIV_NO     != '701'
       AND ORD.DIV_CAS_STU_CD != 'D'
     FETCH FIRST 1 ROW ONLY),0) = 1
  THEN 
    'Y' 
  WHEN coalesce((
    SELECT 1
      FROM ACCP.PID_DSDIT DSD
     WHERE DSD.CAS_UPC_NO  = '0007148602566'
       AND DSD.BIL_STU_CD != '03'
     FETCH FIRST 1 ROW ONLY),0) = 1
  THEN 
    'Y'
  ELSE 
    'N' 
  END                                     AS NON_FM_KMA
--  ,'Y' as NON_FM_KMA
  FROM accp.PID_PDTCA CA 
      ,accp.PID_PDTCO CO 
      ,accp.PID_CASCO CC 
      ,accp.PID_SBCOM SC 
      ,T295 
 WHERE CA.CAS_UPC_NO     = CC.CAS_UPC_NO 
   AND CC.CON_UPC_NO     = CO.CON_UPC_NO 
   AND CC.CON_TYP_CD     = '1' 
   AND CA.LFO_GRP_CLS_ID = SC.LFO_GRP_CLS_ID 
   AND CA.LFO_GRP_SUB_ID = SC.LFO_GRP_SUB_ID 
   AND CA.CPT_DPT_CD     = T295.CPT_DPT_CD 
   AND CA.CAS_UPC_NO     = '0007148602566'
) 
SELECT ITM_NO as itm_no
      ,CAS_UPC_NO as cas_upc_no
      ,CON_UPC_NO as con_upc_no
      ,DIGITS(DECIMAL(CAS_PAK_QY,5)) as cas_pak_qy 
      ,CAS_DSC_TX as cas_dsc_tx
      ,DIGITS(DECIMAL(CAS_LTH_AM*100,5)) as cas_lth_am 
      ,DIGITS(DECIMAL(CAS_WTH_AM*100,5)) as cas_wth_am
      ,DIGITS(DECIMAL(CAS_HGT_AM*100,5)) as cas_hgt_am
      ,CASE 
       WHEN CAS_GRS_WGT_AM < 1000 THEN 
         DIGITS(DECIMAL(CAS_GRS_WGT_AM*100,5)) 
       ELSE 
         '99999' 
       END as cas_grs_wgt_am
      ,CASE 
       WHEN CAS_NET_WGT_AM < 1000 THEN 
         DIGITS(DECIMAL(CAS_NET_WGT_AM*100,5)) 
       ELSE 
         '99999' 
       END as cas_net_wgt_am
      ,LPAD(LTRIM(CAS_SIZ_QY),8,'0') as cas_siz_qy 
      ,CAS_SIZ_CD as cas_siz_cd
      ,FAM_DPT_CD as fam_dpt_cd
      ,FAM_CLS_CD as fam_cls_cd
      ,FAM_SBC_CD as fam_sbc_cd
      ,KLP_KMP_CD as klp_kmp_cd
      ,CAS_DSC_ABB_TX as cas_dsc_abb_tx
      ,CASE FSA_FL
       WHEN 'Y' THEN 
         'Y' 
       ELSE 
         ' ' 
       END AS FSA_FL 
      ,CAS_SHP_FL as cas_shp_fl
      ,EAS_CD as eas_cd
      ,EAS_EFF_DT as eas_eff_dt
      ,DIGITS(DECIMAL(EAS_TAG_PDT_PN*1000,4)) as eas_tag_pdt_pn 
      ,SIZ_UOM_CD as siz_uom_cd
      ,CPT_DPT_CD as cpt_dpt_cd
      ,CORP_CNTL_FL as corp_cntl_fl
      ,TYP_2_BAS as typ_2_bas
      ,NON_FM_KMA AS non_fm_kma
  FROM FIXP 
   FOR FETCH ONLY 
  WITH UR 
;

