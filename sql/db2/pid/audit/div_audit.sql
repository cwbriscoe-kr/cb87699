--change to div db
delete from mdiv;
delete from pdiv;

--change to dbi1/dbp1
WITH WHS AS ( 
-- SELECT SUBSTR(TBL_ELEM_ID,1,5)   AS MAG_WHSE 
--       ,SUBSTR(TBL_ELEM_TEXT,1,3) AS PID_WHSE 
--   FROM PRD.TD1_TBL_DTL 
--  WHERE TBL_ID = 'K006' 
 SELECT '00065' AS MAG_WHSE, '791' AS PID_WHSE FROM PRD.TT1_TRUTH_TBL
  UNION
 SELECT '00461' AS MAG_WHSE, '797' AS PID_WHSE FROM PRD.TT1_TRUTH_TBL
), 
DIV AS (
 SELECT SUBSTR(TBL_ELEM_TEXT,22,2) AS CO_ID
       ,SUBSTR(TBL_ELEM_ID,1,3)    AS DIV_CD
   FROM PRD.TD1_TBL_DTL 
  WHERE TBL_ID = 'K003'
), 
SKUTYP AS ( 
 SELECT SUBSTR(TBL_ELEM_ID,1,2) AS CODE 
   FROM PRD.TD1_TBL_DTL 
  WHERE TBL_ID = 'F026' 
    AND SUBSTR(TBL_ELEM_TEXT,26,1) = 'Y' 
), 
UPCTYP AS ( 
 SELECT TBL_ELEM_ID AS CODE 
   FROM PRD.TD1_TBL_DTL 
  WHERE TBL_ID = 'T013' 
    AND SUBSTR(TBL_ELEM_TEXT,43,1) = 'Y' 
),
RAW AS (
SELECT IS2.SKU_NBR                        AS SKU_NO
      ,CASE OL2.ORG_CO_ID
       WHEN '91' THEN
         CASE SUBSTR(OL2.LOC_ID,1,2)
         WHEN '25' THEN
           '023'
         WHEN '91' THEN
           '701'
         ELSE
           '0' || SUBSTR(OL2.LOC_ID,1,2)
         END
       WHEN '01' THEN
         CASE OL2.ORG_RGN_ID
         WHEN '09' THEN
           '706'
         ELSE
           DIV.DIV_CD
         END
       ELSE
         DIV.DIV_CD
       END                                AS DIV_CD
      ,WHS.PID_WHSE                       AS SRC_ID 
      ,CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM( 
       SV1.MSTR_ART_NBR),14)),1,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       SV1.MSTR_ART_NBR),14)),3,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       SV1.MSTR_ART_NBR),14)),2,1) || 
       SUBSTR(DIGITS(DECIMAL(RTRIM( 
       SV1.MSTR_ART_NBR),14)),4,10),13)   AS CAS_UPC_NO 
  FROM PRD.IS2_ITM_SKU      IS2 
      ,PRD.SV1_SKU_VNDR_DTL SV1 
      ,PRD.SL4_SKU_LOC      SL4 
      ,PRD.VA1_VNDR_ART     VA1 
      ,PRD.OL2_ORG_LOC      OL2
      ,WHS 
      ,DIV
      ,SKUTYP 
      ,UPCTYP 
 WHERE IS2.SKU_NBR            = SV1.SKU_NBR 
   AND IS2.VNDR_NBR           = SV1.VNDR_NBR 
   AND IS2.SKU_TYP_CD         = SKUTYP.CODE 
   AND SV1.SKU_NBR            = VA1.SKU_NBR 
   AND SV1.VNDR_NBR           = VA1.VNDR_NBR 
   AND SV1.PRMY_ALTN_VNDR_IND = 'P'
   AND VA1.SKU_NBR            = SL4.SKU_NBR 
   AND VA1.ART_NBR_ID_CD      = UPCTYP.CODE 
   AND VA1.BAS_ARL_FL         = 'B' 
   AND SL4.REC_STAT_CD        = '01'
   AND SL4.LOC_NBR            = OL2.LOC_ID
   AND OL2.ORG_CO_ID          = DIV.CO_ID
   AND OL2.LOC_TYPE_CD   NOT IN ('04', '08', '09', '10', '99')
   AND IS2.REC_STAT_CD        BETWEEN '20' AND '60'
   AND (SL4.PRMY_SRCE_NBR    = WHS.MAG_WHSE OR
        SL4.DEL_TO_LOC_NBR   = WHS.MAG_WHSE)
   AND EXISTS (SELECT 1
                 FROM PRD.SL4_SKU_LOC SL2 
                WHERE SL2.SKU_NBR = SL4.SKU_NBR
                  AND SL2.LOC_NBR = WHS.MAG_WHSE
                  AND SL2.REC_STAT_CD = '01'
              )
--   AND IS2.SKU_NBR            = '51270148'
   AND LENGTH(LTRIM(RTRIM(SV1.MSTR_ART_NBR))) > 0 
 ORDER BY IS2.SKU_NBR
)
SELECT *
  FROM RAW
 GROUP BY SKU_NO, DIV_CD, SRC_ID, CAS_UPC_NO
 ORDER BY SKU_NO, DIV_CD, SRC_ID
-- FETCH FIRST 1000 ROWS ONLY
  WITH UR 
;
--EXPORT ABOVE TO DIV.MDIV

WITH BASE1 AS (
SELECT CAS_UPC_NO        AS CAS_UPC_NO
      ,BIL_DIV_NO        AS DIV_CD
      ,DIV_CAS_STU_CD    AS STU_CD
  FROM PRD.PID_ORDEN
 WHERE SRC_ID = '791'
 GROUP BY CAS_UPC_NO, BIL_DIV_NO, DIV_CAS_STU_CD
 ORDER BY CAS_UPC_NO, BIL_DIV_NO
),
BASE2 AS (
  SELECT CAS_UPC_NO
        ,DIV_CD
        ,COUNT(*) AS CNT
    FROM BASE1
   GROUP BY CAS_UPC_NO, DIV_CD
   ORDER BY CAS_UPC_NO, DIV_CD
)
SELECT BASE2.CAS_UPC_NO
      ,BASE2.DIV_CD
      ,COALESCE((SELECT DIV_CAS_STU_CD 
                   FROM PRD.PID_ORDEN ORD 
                  WHERE ORD.CAS_UPC_NO     = BASE2.CAS_UPC_NO
                    AND ORD.BIL_DIV_NO     = BASE2.DIV_CD
                    AND ORD.SRC_ID         = '791'
                    AND ORD.DIV_CAS_STU_CD = 'A'
                  FETCH FIRST 1 ROW ONLY),'D') AS STU_CD
  FROM BASE2
  WITH UR
;
--EXPORT ABOVE TO DIV.PDIV

--NOW SWITCH TO DIV DB SOURCE AND ADD INDEX TO PDIV
drop index pdiv_idx_1;
create unique index pdiv_idx_1 on pdiv (cas_upc_no, div_cd);

select * from (
select mdiv.sku_no
      ,substr(mdiv.cas_upc_no,1,1)||substr(mdiv.cas_upc_no,3,1)||
       substr(mdiv.cas_upc_no,2,1)||substr(mdiv.cas_upc_no,4,10) as cas_upc_no
      ,mdiv.div_cd
      ,mdiv.src_id
      ,coalesce((select stu_cd
                   from pdiv pdiv
                  where pdiv.cas_upc_no = mdiv.cas_upc_no
                    and pdiv.div_cd     = mdiv.div_cd),'N') as pid_sts
  from mdiv mdiv
 where mdiv.div_cd != '706'
) as results
 where results.pid_sts in('N','D')
--   and div_cd = '706'
;
                  
