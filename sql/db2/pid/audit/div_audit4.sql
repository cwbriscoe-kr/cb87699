--change to div db
drop table mdiv;
drop table pdiv;
drop table pwhs;
drop table results;

--change to dbi1/dbp1
WITH DIV AS (
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
SKU AS (
 SELECT DISTINCT 
        SL4.SKU_NBR                  AS SKU_NBR
       ,SL4.LOC_NBR                  AS WHSE_NBR
   FROM PRD.IS2_ITM_SKU      IS2
       ,PRD.SV1_SKU_VNDR_DTL SV1  
       ,PRD.VA1_VNDR_ART     VA1
       ,PRD.SL4_SKU_LOC      SL4
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
    AND IS2.REC_STAT_CD       IN ('20','30','40')
    AND SL4.LOC_NBR           IN ('00065','00461')
    AND SL4.REC_STAT_CD        = '01'
    AND LENGTH(LTRIM(RTRIM(SV1.MSTR_ART_NBR))) > 0 
),
RAW AS (
SELECT SKU.SKU_NBR                        AS SKU_NBR
      ,SKU.WHSE_NBR                       AS WHSE_NBR
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
           CASE SUBSTR(OL2.LOC_ID,1,2)
           WHEN '40' THEN
             '706'
           ELSE
             '701'
           END
         ELSE
           DIV.DIV_CD
         END
       ELSE
         DIV.DIV_CD
       END                                AS DIV_CD
--      ,SL4.PRMY_SRCE_NBR                  AS PRIM_WHSE_NBR
      ,CASE LENGTH(TRIM(SL4.PRMY_SRCE_NBR))
       WHEN 5 THEN
         SL4.PRMY_SRCE_NBR
       ELSE
         SL4.DEL_TO_LOC_NBR
       END                                AS PRIM_WHSE_NBR
      ,COALESCE((
         SELECT 'Y' 
           FROM PRD.PIE_PID_INT_ERRS PIE
          WHERE PIE.SKU_NBR = SKU.SKU_NBR
            AND PIE.SEQ_NBR = 1),'N')     AS IERR
  FROM PRD.SL4_SKU_LOC      SL4 
      ,PRD.OL2_ORG_LOC      OL2
      ,SKU
      ,DIV
 WHERE SL4.SKU_NBR            = SKU.SKU_NBR
   AND SL4.REC_STAT_CD        = '01'
   AND SL4.LOC_NBR            = OL2.LOC_ID
   AND OL2.ORG_CO_ID          = DIV.CO_ID
   AND OL2.LOC_TYPE_CD   NOT IN ('04', '08', '09', '10', '99')
--   AND SL4.PRMY_SRCE_NBR    IN ('00065','00461')
   AND (SL4.PRMY_SRCE_NBR     = SKU.WHSE_NBR OR
        SL4.DEL_TO_LOC_NBR    = SKU.WHSE_NBR)
),
DIVAUTH AS (
 SELECT *
   FROM RAW
  GROUP BY SKU_NBR, WHSE_NBR, DIV_CD, PRIM_WHSE_NBR, IERR
)
SELECT DIVAUTH.SKU_NBR
      ,DIVAUTH.DIV_CD
      ,CASE DIVAUTH.WHSE_NBR
       WHEN '00065' THEN
         '791'
       WHEN '00461' THEN
         '797'
       ELSE
         'XXX'
       END                                 AS SRC_ID   
      ,CASE DIVAUTH.PRIM_WHSE_NBR
        WHEN '00065' THEN
          '791'
        WHEN '00461' THEN
          '797'
        ELSE
          'XXX'
        END                                 AS PRIM_SRC_ID   
       ,CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM( 
        SV1.MSTR_ART_NBR),14)),1,1) || 
        SUBSTR(DIGITS(DECIMAL(RTRIM( 
        SV1.MSTR_ART_NBR),14)),3,1) || 
        SUBSTR(DIGITS(DECIMAL(RTRIM( 
        SV1.MSTR_ART_NBR),14)),2,1) || 
        SUBSTR(DIGITS(DECIMAL(RTRIM( 
        SV1.MSTR_ART_NBR),14)),4,10),13)    AS CAS_UPC_NO 
       ,CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM( 
        VA1.ART_NBR),14)),1,1) || 
        SUBSTR(DIGITS(DECIMAL(RTRIM( 
        VA1.ART_NBR),14)),3,1) || 
        SUBSTR(DIGITS(DECIMAL(RTRIM( 
        VA1.ART_NBR),14)),2,1) || 
        SUBSTR(DIGITS(DECIMAL(RTRIM( 
        VA1.ART_NBR),14)),4,10),13)         AS BAS_UPC_NO 
       ,DIGITS(DECIMAL(FI1.FT_LVL06_CD,3))  AS DEPT_CD
       ,DIGITS(DECIMAL(FI1.FT_LVL08_CD,3))  AS CLS_CD
       ,CASE 
        WHEN DIVAUTH.DIV_CD = '705' 
         AND SV1.MDSE_FLOW_CD = 'WHP' THEN
          SPACE(4)
        WHEN SV1.MDSE_FLOW_CD = 'ALC' THEN
          'ALOC'
        ELSE 
          'FMWR' 
        END                                AS FLOW_CD
       ,IS2.REC_STAT_CD                    AS SKU_STS
       ,IS2.SKU_TYP_CD                     AS SKU_TYP
       ,IS2.SKU_VLD_FR_DT                  AS VLD_FR_DT
       ,REPLACE(REPLACE(
        IS2.DESC_LNG_TXT,',',' '),'"',' ') AS SKU_DESC
       ,MR1.MDN_RTL_AMT                    AS MDN_RTL
       ,DIVAUTH.IERR                       AS IERR
   FROM PRD.IS2_ITM_SKU      IS2
       ,PRD.SV1_SKU_VNDR_DTL SV1 
       ,PRD.VA1_VNDR_ART     VA1 
       ,PRD.MR1_PRC_MDN_RTL  MR1
       ,PRD.FI1_FT_ITM       FI1
       ,DIVAUTH
  WHERE IS2.SKU_NBR            = DIVAUTH.SKU_NBR
    AND SV1.SKU_NBR            = IS2.SKU_NBR
    AND VA1.SKU_NBR            = SV1.SKU_NBR
    AND MR1.SKU_NBR            = VA1.SKU_NBR
    AND IS2.ITM_NBR            = FI1.ITM_NBR
    AND FI1.REC_STAT_CD        = '01'
    AND VA1.BAS_ARL_FL         = 'B' 
    AND SV1.PRMY_ALTN_VNDR_IND = 'P'
  ORDER BY SKU_NBR, DIV_CD, SRC_ID
-- fetch first 1 row only
  WITH UR 
;
--EXPORT ABOVE TO DIV.MDIV

WITH BASE1 AS (
SELECT CAS_UPC_NO        AS CAS_UPC_NO
      ,SRC_ID            AS SRC_ID
      ,BIL_DIV_NO        AS DIV_CD
      ,DIV_CAS_STU_CD    AS STU_CD
  FROM PRD.PID_ORDEN
 WHERE SRC_ID IN ('791', '797')
 GROUP BY CAS_UPC_NO, SRC_ID, BIL_DIV_NO, DIV_CAS_STU_CD
 ORDER BY CAS_UPC_NO, SRC_ID, BIL_DIV_NO
),
BASE2 AS (
  SELECT CAS_UPC_NO
        ,SRC_ID
        ,DIV_CD
        ,COUNT(*) AS CNT
    FROM BASE1
   GROUP BY CAS_UPC_NO, SRC_ID, DIV_CD
   ORDER BY CAS_UPC_NO, SRC_ID, DIV_CD
)
SELECT BASE2.CAS_UPC_NO
      ,BASE2.SRC_ID
      ,BASE2.DIV_CD
      ,COALESCE((SELECT DIV_CAS_STU_CD 
                   FROM PRD.PID_ORDEN ORD 
                  WHERE ORD.CAS_UPC_NO     = BASE2.CAS_UPC_NO
                    AND ORD.SRC_ID         = BASE2.SRC_ID
                    AND ORD.BIL_DIV_NO     = BASE2.DIV_CD
                    AND ORD.DIV_CAS_STU_CD IN ('A', 'I')
                  FETCH FIRST 1 ROW ONLY),'D') AS DIV_STU_CD
  FROM BASE2
  WITH UR
;
--EXPORT ABOVE TO DIV.PDIV

WITH WHS AS (
  SELECT CASE
         WHEN TXF_CAS_UPC_NO > ' ' THEN
           TXF_CAS_UPC_NO
         ELSE
           CAS_UPC_NO
         END AS CAS_UPC_NO
        ,CASE
         WHEN TXF_CON_UPC_NO > ' ' THEN
           TXF_CON_UPC_NO
         ELSE
           CON_UPC_NO
         END AS BAS_UPC_NO
        ,SRC_ID AS SRC_ID
        ,SUBSTR(ITM_NO,1,8) AS SKU_NBR
        ,BIL_STU_CD AS WHS_STU_CD
        ,LIN_NO as LIN_NO
    FROM PRD.PID_WHSCA
   WHERE SRC_ID IN ('791','797')
)
SELECT * FROM WHS
;
--EXPORT ABOVE TO DIV.PWHS

--NOW SWITCH TO DIV DB SOURCE AND AND INDEX TO PDIV
drop index pdiv_idx_1;
drop index pwhs_idx_1;
create unique index pdiv_idx_1 on pdiv (cas_upc_no, src_id, div_cd);
create unique index pwhs_idx_1 on pwhs (cas_upc_no, src_id);
create index pwhs_idx_2 on pwhs (sku_nbr, src_id);

select * from (
select t1.sku_nbr
      ,t1.sku_desc
      ,t1.sku_sts
      ,t1.sku_typ
      ,t1.dept_cd
      ,t1.cls_cd
      ,t1.flow_cd
      ,t1.mdn_rtl
      ,t1.vld_fr_dt
      ,substr(t1.cas_upc_no,1,1)||substr(t1.cas_upc_no,3,1)||
       substr(t1.cas_upc_no,2,1)||substr(t1.cas_upc_no,4,10) as cas_upc_no
      ,substr(t1.bas_upc_no,1,1)||substr(t1.bas_upc_no,3,1)||
       substr(t1.bas_upc_no,2,1)||substr(t1.bas_upc_no,4,10) as bas_upc_no
      ,t1.div_cd
      ,t1.src_id
      ,t1.prim_src_id
      ,coalesce((select div_stu_cd
                   from pdiv pdiv
                  where pdiv.cas_upc_no = t1.cas_upc_no
                    and pdiv.src_id     = t1.src_id
                    and pdiv.div_cd     = t1.div_cd),' ') as div_sts
      ,coalesce((select case
                        when whs_stu_cd = '01' then 'A'
                        when whs_stu_cd = '03' then 'D'
                        when whs_stu_cd = '02' then 'T'
                        when whs_stu_cd = '04' then 'O'
                        else '?' end
                   from pwhs
                  where pwhs.cas_upc_no = t1.cas_upc_no
                    and pwhs.src_id     = t1.src_id
                   limit 1),' ') as whs_sts
      ,case
       when t1.sku_typ = '55' then
         'N'
       when t1.src_id = t1.prim_src_id then
         'Y' 
       else
         'N'
       end as scan_flg
      ,t1.ierr
      ,coalesce((select lin_no
                   from pwhs
                  where pwhs.sku_nbr = t1.sku_nbr
                    and pwhs.src_id  = t1.src_id
                    and pwhs.cas_upc_no != t1.cas_upc_no
                  limit 1),' ') as lin_no
      ,coalesce((select substr(pwhs.cas_upc_no,1,1)||substr(pwhs.cas_upc_no,3,1)||
                        substr(pwhs.cas_upc_no,2,1)||substr(pwhs.cas_upc_no,4,10)
                   from pwhs
                  where pwhs.sku_nbr = t1.sku_nbr
                    and pwhs.src_id  = t1.src_id
                    and pwhs.cas_upc_no != t1.cas_upc_no
                  limit 1),' ') as whs_cas
      ,coalesce((select substr(pwhs.bas_upc_no,1,1)||substr(pwhs.bas_upc_no,3,1)||
                        substr(pwhs.bas_upc_no,2,1)||substr(pwhs.bas_upc_no,4,10)
                   from pwhs
                  where pwhs.sku_nbr = t1.sku_nbr
                    and pwhs.src_id  = t1.src_id
                    and pwhs.cas_upc_no != t1.cas_upc_no
                    and pwhs.bas_upc_no != t1.bas_upc_no
                  limit 1),' ') as whs_bas
  from mdiv t1
 where t1.div_cd not in  ('701','701')
   and t1.src_id in ('791', '797')              
) as results
 where results.div_sts in(' ','D')
;

select *
  from results;

select * 
  from results
 where sku_nbr in (
'01080643',
'01103847',
'01145243',
'01176544',
'01186147',
'01235548',
'01292749',
'01326444'
);

select * 
  from mdiv
 where sku_nbr = '08479310';