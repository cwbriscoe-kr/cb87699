drop table mag;
drop table pid;

WITH SKUTYPE AS ( 
 SELECT SUBSTR(TBL_ELEM_ID,1,2)           AS CODE 
   FROM PRD.TD1_TBL_DTL 
  WHERE TBL_ID = 'F026' 
    AND SUBSTR(TBL_ELEM_TEXT,26,1) = 'Y' 
), 
UPCTYPE AS ( 
 SELECT TBL_ELEM_ID                       AS CODE 
   FROM PRD.TD1_TBL_DTL 
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
      ,CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM( 
       VA1.ART_NBR),14)),1,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       VA1.ART_NBR),14)),3,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       VA1.ART_NBR),14)),2,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       VA1.ART_NBR),14)),4,10),13)        AS CON_UPC_NO
      ,CASE IS2.SKU_TYP_CD
       WHEN '55' THEN
         'Y'
       ELSE
         'N'
       END                                AS SET_SKU
      ,IS2.REC_STAT_CD                    AS SKU_STS 
  FROM PRD.IS2_ITM_SKU      IS2 
      ,PRD.SV1_SKU_VNDR_DTL SV1 
      ,PRD.VA1_VNDR_ART     VA1 
      ,PRD.FI1_FT_ITM       FI1 
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
   AND IS2.REC_STAT_CD        between '10' and '40'
   AND LENGTH(LTRIM(RTRIM(SV1.MSTR_ART_NBR))) > 0
   FOR FETCH ONLY 
  WITH UR 
;

-- ^^^^ save as setsku.mag

SELECT CAS_UPC_NO AS CAS_UPC_NO
      ,CASE CAS_SHP_FL
       WHEN 'Y' THEN
         'Y'
       ELSE
         'N'
       END        AS SET_SKU
  FROM PRD.PID_PDTCA PDTCA
 WHERE NOT EXISTS (
       SELECT 1
         FROM PRD.PID_DSDIT DSDIT
        WHERE DSDIT.CAS_UPC_NO = PDTCA.CAS_UPC_NO
          AND DSDIT.BIL_STU_CD != '03'
        FETCH FIRST 1 ROW ONLY
       )
   AND NOT EXISTS (
       SELECT 1
         FROM PRD.PID_ORDEN ORDEN
        WHERE ORDEN.CAS_UPC_NO = PDTCA.CAS_UPC_NO
          AND ORDEN.BIL_DIV_NO != '701'
          AND ORDEN.DIV_CAS_STU_CD != 'D'
        FETCH FIRST 1 ROW ONLY
       )
  AND NOT EXISTS (
      SELECT 1
        FROM PRD.PID_WHSCA WHSCA
       WHERE WHSCA.CAS_UPC_NO = PDTCA.CAS_UPC_NO
         AND WHSCA.SRC_ID NOT IN ('791','792','794','797')
         AND WHSCA.BIL_STU_CD != '03'
       FETCH FIRST 1 ROW ONLY
      )
;

-- ^^^^ save as setsku.pid

create index mag_idx_1 on mag (cas_upc_no);
create unique index pid_idx_1 on pid (cas_upc_no);

select substr(mag.itm_no,1,8)  as sku_nbr
      ,substr(mag.cas_upc_no,1,1)||substr(mag.cas_upc_no,3,1)||
       substr(mag.cas_upc_no,2,1)||substr(mag.cas_upc_no,4,10) as mag_case
      ,substr(mag.con_upc_no,1,1)||substr(mag.con_upc_no,3,1)||
       substr(mag.con_upc_no,2,1)||substr(mag.con_upc_no,4,10) as mag_base
      ,mag.sku_sts
      ,mag.set_sku as mag_set_sku
      ,pid.set_sku as pid_shipper
  from mag, pid
 where mag.cas_upc_no = pid.cas_upc_no
   and mag.set_sku   != pid.set_sku
 order by sku_nbr
--limit 1000
;