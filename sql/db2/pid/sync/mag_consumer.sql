WITH SKUTYP AS ( 
 SELECT SUBSTR(TBL_ELEM_ID,1,2)           AS CODE 
   FROM ACCP.TD1_TBL_DTL 
  WHERE TBL_ID      = 'F026' 
    AND ORG_CO_NBR  = '1' 
    AND ORG_RGN_NBR = '00' 
    AND SUBSTR(TBL_ELEM_TEXT,26,1) = 'Y' 
), 
UPCTYP AS ( 
 SELECT TBL_ELEM_ID                       AS CODE 
   FROM ACCP.TD1_TBL_DTL 
  WHERE TBL_ID      = 'T013' 
    AND ORG_CO_NBR  = '1' 
    AND ORG_RGN_NBR = '00' 
    AND SUBSTR(TBL_ELEM_TEXT,43,1) = 'Y' 
),
NSKU AS ( 
 SELECT IS2.SKU_NBR               AS SKU 
       ,IS2.SKU_NBR               AS CPN_SKU 
       ,IS2.SKU_TYP_CD            AS SKU_TYP 
       ,CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM( 
        SV1.MSTR_ART_NBR),14)),1,1) || 
        SUBSTR(DIGITS(DECIMAL(RTRIM( 
        SV1.MSTR_ART_NBR),14)),3,1) || 
        SUBSTR(DIGITS(DECIMAL(RTRIM( 
        SV1.MSTR_ART_NBR),14)),2,1) || 
        SUBSTR(DIGITS(DECIMAL(RTRIM( 
        SV1.MSTR_ART_NBR),14)),4,10),13) 
                                  AS CAS_UPC_NO 
       ,'0'                       AS CPN_FLG 
       ,0                         AS CPN_SKU_QY 
       ,0.00                      AS CPN_SKU_CST_AM 
   FROM ACCP.IS2_ITM_SKU        IS2 
       ,ACCP.SV1_SKU_VNDR_DTL   SV1 
       ,ACCP.VA1_VNDR_ART       VA1 
       ,UPCTYP, SKUTYP
  WHERE IS2.SKU_NBR            = '96136614'
    AND IS2.REC_STAT_CD        > '10' 
    AND IS2.SKU_NBR            = SV1.SKU_NBR 
    AND IS2.VNDR_NBR           = SV1.VNDR_NBR 
    AND SV1.SKU_NBR            = VA1.SKU_NBR 
    AND SV1.VNDR_NBR           = VA1.VNDR_NBR 
    AND SV1.PRMY_ALTN_VNDR_IND = 'P' 
    AND VA1.BAS_ARL_FL         = 'B' 
    AND IS2.SKU_TYP_CD = SKUTYP.CODE 
    AND VA1.ART_NBR_ID_CD = UPCTYP.CODE
), 
SSKU AS ( 
 SELECT NSKU.SKU                  AS SKU 
       ,SC9.COMP_SKU_NBR          AS CPN_SKU 
       ,NSKU.SKU_TYP              AS SKU_TYP 
       ,NSKU.CAS_UPC_NO           AS CAS_UPC_NO 
       ,'1'                       AS CPN_FLG 
       ,SC9.COMP_SKU_QTY          AS CPN_SKU_QY 
       ,CM1.COST_AMT/CM1.COST_UNT AS CPN_SKU_CST_AM 
   FROM ACCP.SC9_SET_SKU_COMP   SC9 
       ,ACCP.IS2_ITM_SKU        IS2 
       ,ACCP.SV1_SKU_VNDR_DTL   SV1 
       ,ACCP.CM1_MDSE_COST_MSTR CM1 
       ,NSKU 
  WHERE NSKU.SKU_TYP           = '55' 
    AND IS2.SKU_NBR            = NSKU.SKU 
    AND SC9.SKU_NBR            = IS2.SKU_NBR 
    AND SC9.COMP_SKU_NBR       = CM1.SKU_NBR 
    AND CM1.VNDR_NBR           = SV1.VNDR_NBR 
    AND SV1.SKU_NBR            = SC9.COMP_SKU_NBR 
    AND SV1.PRMY_ALTN_VNDR_IND = 'P' 
), 
SKULIST AS ( 
 SELECT * FROM NSKU 
  UNION 
 SELECT * FROM SSKU 
), 
RESULTS AS ( 
 SELECT SKULIST.SKU || '0'               AS ITM_NO 
       ,SKULIST.CAS_UPC_NO                AS CAS_UPC_NO 
       ,CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM( 
        VA1.ART_NBR),14)),1,1) || 
        SUBSTR(DIGITS(DECIMAL(RTRIM( 
        VA1.ART_NBR),14)),3,1) || 
        SUBSTR(DIGITS(DECIMAL(RTRIM( 
        VA1.ART_NBR),14)),2,1) || 
        SUBSTR(DIGITS(DECIMAL(RTRIM( 
        VA1.ART_NBR),14)),4,10),13)       AS CON_UPC_NO 
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
        END                               AS CAS_PAK_QY 
       ,CASE SKULIST.CPN_FLG 
        WHEN '0' THEN 
          CASE VA1.BAS_ARL_FL 
          WHEN 'B' THEN 
            '1' 
          ELSE 
            ' ' 
          END 
        ELSE 
          'P' 
        END                               AS CON_TYP_CD 
       ,COALESCE( 
        (SELECT SD3.PLU_DESC || SPACE(6) 
           FROM ACCP.SD3_SD_SKU_DTL SD3 
          WHERE SD3.SKU_NBR = IS2.SKU_NBR 
        ),SUBSTR(IS2.DESC_SHRT_TXT,1,18) 
       )                                  AS CON_DSC_ABB_TX
      ,IS2.DESC_SHRT_TXT || SPACE(10)     AS CON_DSC_TX 
      ,CASE IS2.FSA_FLG 
       WHEN 'Y' THEN 
         'Y' 
       ELSE 
         ' ' 
       END                                AS FSA_FL 
      ,DIGITS(DECIMAL(SKULIST.CPN_SKU_QY,9)) 
                                          AS CPN_SKU_QY 
      ,DIGITS(DECIMAL(SKULIST.CPN_SKU_CST_AM*100,7)) 
                                          AS CPN_SKU_CST_AM
      ,IS2.DESC_LNG_TXT                   AS SKU_DSC_TX 
      ,CASE 
       WHEN SV1.VNDR_CLR_DESC < SPACE(20) THEN 
         SPACE(20) 
       ELSE 
         SV1.VNDR_CLR_DESC 
       END                                AS CON_CLX_TX 
      ,CASE 
       WHEN VNDR_SIZE_DESC < SPACE(20) THEN 
         SPACE(20) 
       ELSE 
         SV1.VNDR_SIZE_DESC 
       END                                AS CON_SIZ_TX 
      ,CASE 
       WHEN SV1.STY_NBR < SPACE(15) THEN 
         SPACE(15) 
       ELSE 
         SV1.STY_NBR 
       END                                AS SKU_STY_TX 
      ,IS2.SKU_TYP_CD                     AS SKU_TYP_CD 
      ,CASE 
       WHEN OUT_PERIOD_DT > SPACE(10) THEN 
         COALESCE( 
         (SELECT GREG_DT 
            FROM ACCP.CAL_PRD_CALENDAR 
           WHERE PRD_NBR = COALESCE(DECIMAL( 
                           SUBSTR(OUT_PERIOD_DT,1,2)),0) 
             AND PRD_YY  = COALESCE(DECIMAL( 
                           SUBSTR(OUT_PERIOD_DT,3,4)),0) 
             AND PRD_WK  = 1 
             AND PRD_DAY = 1 
         ),'9999-12-31') 
       ELSE 
         '9999-12-31' 
       END                                AS CON_OUT_DT 
      ,IS2.BRND_NM                        AS FMY_BRN_NAM_TX
      ,SV1.MSTR_ART_NBR                   AS MAG_CAS_NO 
      ,VA1.ART_NBR                        AS MAG_CON_NO 
    FROM ACCP.IS2_ITM_SKU        IS2 
        ,ACCP.SV1_SKU_VNDR_DTL   SV1 
        ,ACCP.VA1_VNDR_ART       VA1 
        ,ACCP.IC1_ITM_CHOICE_DTL IC1 
        ,SKULIST, SKUTYP, UPCTYP
   WHERE IS2.SKU_NBR            = SKULIST.CPN_SKU 
     AND IS2.REC_STAT_CD        > '10' 
     AND IS2.SKU_NBR            = SV1.SKU_NBR 
     AND IS2.VNDR_NBR           = SV1.VNDR_NBR 
     AND SV1.SKU_NBR            = VA1.SKU_NBR 
     AND SV1.VNDR_NBR           = VA1.VNDR_NBR 
     AND SV1.PRMY_ALTN_VNDR_IND = 'P' 
     AND LENGTH(LTRIM(RTRIM(SV1.MSTR_ART_NBR))) > 0 
     AND IS2.CHOICE_KEY_NO      = IC1.CHOICE_KEY_NO 
     AND IS2.SKU_TYP_CD = SKUTYP.CODE
     AND VA1.ART_NBR_ID_CD = UPCTYP.CODE
     AND (SKULIST.CPN_FLG = '0' OR 
         (SKULIST.CPN_FLG = '1' AND VA1.BAS_ARL_FL = 'B')) 
     AND (IS2.SKU_TYP_CD != '55' OR 
         (IS2.SKU_TYP_CD  = '55' AND VA1.BAS_ARL_FL = 'B')) 
) 
SELECT CASE CON_TYP_CD 
       WHEN '1' THEN 
         '0' || CON_UPC_NO 
       ELSE 
         '1' || CON_UPC_NO 
       END                                AS SRT_KEY 
      ,RESULTS.* 
  FROM RESULTS 
 ORDER BY SRT_KEY 
   FOR FETCH ONLY 
  WITH UR 
;