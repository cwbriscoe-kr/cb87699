WITH SKUTYPE AS ( 
 SELECT SUBSTR(TBL_ELEM_ID,1,2)           AS CODE 
   FROM PRD.TD1_TBL_DTL 
  WHERE TBL_ID = 'F026' 
    AND SUBSTR(TBL_ELEM_TEXT,26,1) = 'Y' 
), 
UPCTYPE AS ( 
 SELECT TBL_ELEM_ID                       AS CODE 
       ,SUBSTR(TBL_ELEM_TEXT,45,1)        AS RTL_FL 
   FROM PRD.TD1_TBL_DTL 
  WHERE TBL_ID = 'T013' 
    AND SUBSTR(TBL_ELEM_TEXT,43,1) = 'Y' 
),
MAG AS (
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
      ,SV1.MSTR_ART_TYP_CD                AS CAS_TYP_CD
      ,SV1.MSTR_ART_NBR                   AS MSTR_ART_NBR
      ,SV1.MSTR_PACK_QTY                  AS MSTR_PACK_QTY
      ,DIGITS(DECIMAL(FI1.FT_LVL06_CD,4)) AS FAM_DPT_CD
      ,DIGITS(DECIMAL(FI1.FT_LVL08_CD,4)) AS FAM_CLS_CD
      ,DIGITS(DECIMAL(FI1.FT_LVL09_CD,4)) AS FAM_SBC_CD
      ,IS2.DESC_LNG_TXT                   AS MAG_DESC
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
   AND SV1.MSTR_ART_TYP_CD    = 'CS'
   AND VA1.ART_NBR_ID_CD      = UPCTYPE.CODE
   AND VA1.BAS_ARL_FL         = 'B' 
--   AND IS2.REC_STAT_CD        BETWEEN '20' and '60'
   AND LENGTH(LTRIM(RTRIM(SV1.MSTR_ART_NBR))) > 0
),
DATA AS (
SELECT SUBSTR(MAG.ITM_NO,1,8) AS SKU_NBR
      ,MAG.CAS_TYP_CD         AS MAG_CAS_TYP_CD
      ,MAG.MSTR_ART_NBR       AS MAG_MSTR_ART_NBR
      ,PID.CAS_UPC_NO         AS PID_CAS_UPC_NO
      ,PID.CON_UPC_NO         AS PID_CON_UPC_NO
      ,MAG.MSTR_PACK_QTY      AS MAG_PAK_QY
      ,PID.CAS_CON_QY         AS PID_PAK_QY
      ,PDT.CAS_ADD_DT         AS CAS_ADD_DT
      ,MAG.MAG_DESC           AS MAG_DESC
      ,PDT.CAS_DSC_TX         AS PID_DESC
  FROM MAG              
      ,PRD.K15_PID_CASCO PID
      ,PRD.K14_PID_PDTCA PDT
      ,PRD.K26_PID_SBCOM SBC
 WHERE MAG.CON_UPC_NO = PID.CON_UPC_NO
   AND PID.CAS_UPC_NO = PDT.CAS_UPC_NO
   AND PDT.CAS_DCN_DT = '0001-01-01'
   AND PDT.LFO_GRP_CLS_ID = SBC.LFO_GRP_CLS_ID
   AND PDT.LFO_GRP_SUB_ID = SBC.LFO_GRP_SUB_ID
   AND MAG.FAM_DPT_CD     = SBC.FAM_DPT_CD
   AND MAG.FAM_CLS_CD     = SBC.FAM_CLS_CD
   AND MAG.FAM_SBC_CD     = SBC.FAM_SBC_CD
   AND PID.CON_TYP_CD              = '1'
   AND SUBSTR(PID.CAS_UPC_NO,1,3) != '040'
   AND NOT EXISTS (
       SELECT '1'
         FROM PRD.K15_PID_CASCO PID2
        WHERE PID.CON_UPC_NO = PID2.CON_UPC_NO
          AND PID.CON_TYP_CD = PID2.CON_TYP_CD
          AND PID2.CAS_UPC_NO = MAG.CAS_UPC_NO
          AND SUBSTR(PID2.CAS_UPC_NO,1,3) != '040'
   )
),
bupc as (
  select DATA.PID_CAS_UPC_NO AS OUPC
        ,DATA.PID_CAS_UPC_NO as bupc
    from DATA
),
gupc as (
  select oupc
        ,substr(bupc,1,1)||substr(bupc,3,1)
       ||substr(bupc,2,1)||substr(bupc,4,10) as gupc
    from bupc
),
chkdgt1 as (
  select oupc
        ,cast (substr(gupc,1,1) as integer) as d1
        ,cast (substr(gupc,2,1) as integer) as d2
        ,cast (substr(gupc,3,1) as integer) as d3
        ,cast (substr(gupc,4,1) as integer) as d4
        ,cast (substr(gupc,5,1) as integer) as d5
        ,cast (substr(gupc,6,1) as integer) as d6
        ,cast (substr(gupc,7,1) as integer) as d7
        ,cast (substr(gupc,8,1) as integer) as d8
        ,cast (substr(gupc,9,1) as integer) as d9
        ,cast (substr(gupc,10,1) as integer) as d10
        ,cast (substr(gupc,11,1) as integer) as d11
        ,cast (substr(gupc,12,1) as integer) as d12
        ,cast (substr(gupc,13,1) as integer) as d13
    from gupc
),
chkdgt2 as (
  select oupc
        ,d1*3+d2*1+d3*3+d4*1+d5*3+d6*1+d7*3
        +d8*1+d9*3+d10*1+d11*3+d12*1+d13*3  as chksum
    from chkdgt1
),
chkdgt3 as (
  select oupc
        ,((chksum/10)*10+10) - chksum as digit
    from chkdgt2
),
chkdgt as (
  select oupc
        ,case
           when digit = 10 then
             '0'
           else
             substr(digits(digit),10,1)
         end as chkdgt 
    from chkdgt3
),
magupc as (
  select gupc.oupc
        ,(gupc.gupc)||(chkdgt.chkdgt)
      as magupc
    from gupc, chkdgt
   where gupc.oupc = chkdgt.oupc
)

SELECT data.sku_nbr
--      ,data.mag_cas_typ_cd
      ,data.mag_mstr_art_nbr
      ,magupc.magupc as new_cas
      ,data.mag_pak_qy
      ,data.pid_pak_qy
--      ,data.mag_desc
--      ,data.pid_desc
  from data, magupc
 WHERE DATA.PID_CAS_UPC_NO = magupc.OUPC
   AND DATA.CAS_ADD_DT = (
         SELECT MAX(CAS_ADD_DT)
           FROM DATA D2
          WHERE DATA.SKU_NBR = D2.SKU_NBR
   )
 ORDER BY SKU_NBR
  WITH UR 
;