WITH SKUTYPE AS ( 
 SELECT SUBSTR(TBL_ELEM_ID,1,2)           AS CODE 
   FROM ACCP.TD1_TBL_DTL 
  WHERE TBL_ID = 'F026' 
    AND SUBSTR(TBL_ELEM_TEXT,26,1) = 'Y' 
), 
UPCTYPE AS ( 
 SELECT TBL_ELEM_ID                       AS CODE 
       ,SUBSTR(TBL_ELEM_TEXT,45,1)        AS RTL_FL 
   FROM ACCP.TD1_TBL_DTL 
  WHERE TBL_ID = 'T013' 
    AND SUBSTR(TBL_ELEM_TEXT,43,1) = 'Y' 
) 
SELECT IS2.SKU_NBR  || '0'                AS ITM_NO 
      ,CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM( 
       SV1.MSTR_ART_NBR),14)),1,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       SV1.MSTR_ART_NBR),14)),3,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       SV1.MSTR_ART_NBR),14)),2,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       SV1.MSTR_ART_NBR),14)),4,10),13)   AS CAS_UPC_NO 
      ,IS2.REC_STAT_CD                    AS REC_STAT 
      ,CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM( 
       VA1.ART_NBR),14)),1,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       VA1.ART_NBR),14)),3,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       VA1.ART_NBR),14)),2,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       VA1.ART_NBR),14)),4,10),13)        AS CON_UPC_NO 
      ,CASE 
       WHEN SV1.MSTR_PACK_QTY > 999 THEN 
         '00999' 
       ELSE 
         CASE IS2.SKU_TYP_CD
         WHEN '55' THEN
           '00001'
         ELSE	
            DIGITS(DECIMAL(SV1.MSTR_PACK_QTY,5)) 
         END
       END                                AS CAS_PAK_QY 
      ,IS2.DESC_SHRT_TXT                  AS CAS_DSC_TX 
      ,DIGITS(DECIMAL(SV1.MSTR_PACK_LEN,5)) 
                                          AS CAS_LTH_AM 
      ,DIGITS(DECIMAL(SV1.MSTR_PACK_WD,5))
                                          AS CAS_WTH_AM 
      ,DIGITS(DECIMAL(SV1.MSTR_PACK_HT,5))
                                          AS CAS_HGT_AM 
      ,DIGITS(DECIMAL(SV1.MSTR_PACK_WGT,5))
                                          AS CAS_GRS_WGT_AM
      ,'00000'                            AS CAS_NET_WGT_AM
      ,'00000001'                         AS SIZ_QY 
      ,IS2.SELL_UOM                       AS SIZ_CD 
      ,SUBSTR(VNDR_SIZE_DESC,1,10)        AS SIZ_TX 
      ,DIGITS(DECIMAL(FI1.FT_LVL06_CD,4)) AS FAM_DPT_CD 
      ,DIGITS(DECIMAL(FI1.FT_LVL08_CD,4)) AS FAM_CLS_CD 
      ,DIGITS(DECIMAL(FI1.FT_LVL09_CD,4)) AS FAM_SBC_CD 
      ,'?'                                AS PDT_CLS_CD 
      ,COALESCE( 
        (SELECT SUBSTR(T1.TBL_ELEM_TEXT,27,1) 
           FROM ACCP.TD1_TBL_DTL T1 
          WHERE T1.TBL_ID      = 'F022' 
            AND T1.ORG_CO_NBR  = '1' 
            AND T1.ORG_RGN_NBR = '00' 
            AND SUBSTR(T1.TBL_ELEM_ID,1,2) 
                               = IS2.BRND_TYP_CD 
        ),' ' 
       )                                  AS KLP_KMP_CD 
      ,COALESCE( 
        (SELECT SD3.PLU_DESC 
           FROM ACCP.SD3_SD_SKU_DTL SD3 
          WHERE SD3.SKU_NBR    = IS2.SKU_NBR 
        ),SUBSTR(IS2.DESC_SHRT_TXT,1,18) 
       )                                  AS CAS_DSC_ABB_TX
      ,UPCTYPE.RTL_FL                     AS RTL_FL 
      ,'?'                                AS RDM_WGT_FL 
      ,'?'                                AS FSA_FL 
      ,CASE 
       WHEN IS2.SKU_TYP_CD = '55' THEN 
         'Y' 
       ELSE 
         'N' 
       END                                AS CAS_SHP_FL 
      ,'?????'                            AS SHP_MDE_TYP_CD
      ,CASE 
       WHEN SV1.EAS_IND = 'V' THEN 
         SV1.EAS_IND 
       ELSE 
         ' ' 
       END                                AS EAS_CD 
      ,CASE 
       WHEN SV1.EAS_IND = 'V' THEN 
         SV1.REC_CRT_DT 
       ELSE 
         '0001-01-01' 
       END                                AS EAS_EFF_DT 
      ,CASE 
       WHEN SV1.EAS_IND = 'V' THEN 
         1.000 
       ELSE 
         0.000 
       END                                AS EAS_TAG_PDT_PN
      ,'??'                               AS SIZ_UOM_CD 
  FROM ACCP.IS2_ITM_SKU      IS2 
      ,ACCP.SV1_SKU_VNDR_DTL SV1 
      ,ACCP.VA1_VNDR_ART     VA1 
      ,ACCP.FI1_FT_ITM       FI1 
      ,SKUTYPE 
      ,UPCTYPE 
 WHERE IS2.SKU_NBR            = SV1.SKU_NBR 
   AND IS2.VNDR_NBR           = SV1.VNDR_NBR 
   AND IS2.SKU_TYP_CD         = SKUTYPE.CODE 
   AND FI1.ITM_NBR            = IS2.ITM_NBR 
   AND FI1.EFF_FR_DT         <= CURRENT DATE 
   AND FI1.EFF_TO_DT          > CURRENT DATE 
   AND FI1.REC_STAT_CD        = '01' 
   AND SV1.SKU_NBR            = VA1.SKU_NBR 
   AND SV1.VNDR_NBR           = VA1.VNDR_NBR 
   AND SV1.PRMY_ALTN_VNDR_IND = 'P' 
   AND VA1.ART_NBR_ID_CD      = UPCTYPE.CODE 
   AND VA1.BAS_ARL_FL         = 'B' 
   AND IS2.REC_STAT_CD        BETWEEN '20' and '60'
   AND IS2.SKU_NBR            = '18809442'
   AND LENGTH(LTRIM(RTRIM(SV1.MSTR_ART_NBR))) > 0
   FOR FETCH ONLY 
  WITH UR 
;