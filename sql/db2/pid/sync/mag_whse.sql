WITH WHS AS ( 
 SELECT SUBSTR(TBL_ELEM_ID,1,5)   AS MAG_WHSE 
       ,SUBSTR(TBL_ELEM_TEXT,1,3) AS PID_WHSE 
   FROM accp.TD1_TBL_DTL 
  WHERE TBL_ID = 'K006' 
), 
SKUTYP AS ( 
 SELECT SUBSTR(TBL_ELEM_ID,1,2) AS CODE 
   FROM accp.TD1_TBL_DTL 
  WHERE TBL_ID = 'F026' 
    AND SUBSTR(TBL_ELEM_TEXT,26,1) = 'Y' 
), 
UPCTYP AS ( 
 SELECT TBL_ELEM_ID AS CODE 
   FROM accp.TD1_TBL_DTL 
  WHERE TBL_ID = 'T013' 
    AND SUBSTR(TBL_ELEM_TEXT,43,1) = 'Y' 
) 
SELECT WHS.PID_WHSE                       AS SRC_ID 
      ,CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM( 
       SV1.MSTR_ART_NBR),14)),1,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       SV1.MSTR_ART_NBR),14)),3,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       SV1.MSTR_ART_NBR),14)),2,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       SV1.MSTR_ART_NBR),14)),4,10),13)   AS CAS_UPC_NO 
      ,CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM( 
       VA1.ART_NBR),14)),1,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       VA1.ART_NBR),14)),3,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       VA1.ART_NBR),14)),2,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       VA1.ART_NBR),14)),4,10),13)        AS CON_UPC_NO 
      ,SV2.VNDR_NBR                       AS MRC_VND_NO 
      ,IS2.SKU_NBR  || '0'                AS ITM_NO 
      ,CASE SL4.REC_STAT_CD 
       WHEN '01' THEN 
         'A' 
       WHEN '40' THEN 
         'F' 
       ELSE 
         'P' 
       END                                AS BIL_STU_CD 
      ,DIGITS(DECIMAL(FI1.FT_LVL06_CD,3)) AS BYR_ID 
      ,DIGITS(DECIMAL(IS2.STR_ORD_MULT_QTY_3,3)) 
                                          AS ORD_MUL_QY 
      ,CASE 
       WHEN SV2.MSTR_PACK_QTY > 999 THEN 
         '00999' 
       ELSE 
         DIGITS(DECIMAL(SV2.MSTR_PACK_QTY,5)) 
       END                                AS CAS_PAK_QY 
      ,COALESCE(( 
       SELECT DIGITS(DECIMAL(TSK.TASK_NBR,3)) 
         FROM accp.TSK_TASK TSK 
        WHERE TSK.RPLN_GRP_CD = IS2.RPLN_GRP_CD 
          AND TSK.TASK_GRP_CD = 'NFDO' 
          AND TSK.SKU_VLD_FLG = 'Y' 
          AND TSK.LVL04_CD   = FI1.FT_LVL04_CD 
          AND TSK.LVL06_CD   = FI1.FT_LVL06_CD 
       ), '000')                          AS TSK_ID 
      ,CASE SV1.MDSE_FLOW_CD 
       WHEN 'RMA' THEN 
         'R' 
       WHEN 'DTS' THEN 
         'R' 
       WHEN 'ALC' THEN 
         'A' 
       ELSE 
         ' ' 
       END                                AS REP_CD 
      ,CASE VD1.EDI_FLG 
       WHEN 'P' THEN 
         'Y' 
       ELSE 
         ' ' 
       END                                AS VTS_FL
      ,SV2.INNER_PACK_QTY                 AS SLV_PAK_QY
  FROM accp.IS2_ITM_SKU      IS2 
      ,accp.SV1_SKU_VNDR_DTL SV1 
      ,accp.SV1_SKU_VNDR_DTL SV2
      ,accp.SL4_SKU_LOC      SL4 
      ,accp.VA1_VNDR_ART     VA1 
      ,accp.VD1_VNDR_DTL     VD1 
      ,accp.FI1_FT_ITM       FI1 
      ,WHS 
      ,SKUTYP 
      ,UPCTYP 
 WHERE IS2.SKU_NBR            = SV1.SKU_NBR 
   AND IS2.VNDR_NBR           = SV1.VNDR_NBR 
   AND IS2.SKU_TYP_CD         = SKUTYP.CODE 
   AND FI1.ITM_NBR            = IS2.ITM_NBR 
   AND FI1.EFF_FR_DT         <= CURRENT DATE 
   AND FI1.EFF_TO_DT          > CURRENT DATE 
   AND FI1.REC_STAT_CD        = '01' 
   AND SV1.SKU_NBR            = VA1.SKU_NBR 
   AND SV1.VNDR_NBR           = VA1.VNDR_NBR 
   AND SV1.PRMY_ALTN_VNDR_IND = 'P'
   AND SV2.SKU_NBR            = SV1.SKU_NBR
   AND SV2.VNDR_NBR           = SL4.PRMY_SRCE_NBR 
   AND VA1.SKU_NBR            = SL4.SKU_NBR 
   AND VA1.ART_NBR_ID_CD      = UPCTYP.CODE 
   AND VA1.BAS_ARL_FL         = 'B' 
   AND VD1.VNDR_NBR           = IS2.VNDR_NBR 
   AND VD1.VNDR_CO_NBR        = '1' 
   AND VD1.VNDR_RGN_NBR       = '00' 
   AND SL4.LOC_NBR            = WHS.MAG_WHSE 
   AND IS2.REC_STAT_CD        BETWEEN '20' AND '60'
   AND LENGTH(LTRIM(RTRIM(SV1.MSTR_ART_NBR))) > 0 
   FOR FETCH ONLY 
  WITH UR 
;

--are we supposed to use base upc or lead upc for whsca rec in consumer upc field?
