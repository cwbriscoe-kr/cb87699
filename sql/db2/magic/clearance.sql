WITH UPCTYP AS (
 SELECT TBL_ELEM_ID as upc_typ
   FROM prd.TD1_TBL_DTL
  WHERE TBL_ID      = 'T013'
    AND ORG_CO_NBR  = '1'
    AND ORG_RGN_NBR = '00'
    AND SUBSTR(TBL_ELEM_TEXT,43,1) = 'Y'
    AND SUBSTR(TBL_ELEM_TEXT,45,1) = 'Y'
)
SELECT PM2.SKU_NBR
      ,PM2.LOC_NBR
      ,PM2.EFF_FR_DT
      ,PM2.EFF_TO_DT
      ,case
       when pm2.temp_chng_nbr > 0 then 'T'
       else 'P' end as chng_type
      ,case
       when pm2.temp_chng_nbr > 0 then pm2.temp_prc_typ_cd
       else pm2.perm_prc_typ_cd end as prc_typ_cd
      ,PM2.PERM_PRC_TYP_CD
      ,LPAD(VA1.ART_4680_NBR,14,'0') AS ART_CHK
      ,FI1.FT_LVL04_CD
      ,CASE
       WHEN FI1.FT_LVL04_CD = 7 THEN 'PEM'
       WHEN FI1.FT_LVL04_CD = 8 THEN 'HOM'
       WHEN FI1.FT_LVL04_CD = 9 THEN 'ALE'
       ELSE '###'
       END AS DIVISION
      ,FI1.FT_LVL06_CD
--SELECT count(PM2.SKU_NBR)
FROM   PRD.IS2_ITM_SKU IS2
      ,PRD.VA1_VNDR_ART VA1
      ,PRD.FI1_FT_ITM FI1
      ,PRD.PM2_MDSE_PRC_MSTR PM2
      ,UPCTYP
WHERE  ((PM2.PERM_PRC_TYP_CD IN ('07','08','67','68','77','78')
  and    pm2.perm_chng_nbr > 0)
   OR  (PM2.TEMP_PRC_TYP_CD IN ('60','61','62','63','65','66','89')
  and  pm2.temp_chng_nbr > 0))
  AND  PM2.EFF_FR_DT <= CURRENT DATE
  AND  PM2.EFF_TO_DT > CURRENT DATE
  AND  PM2.LOC_NBR IN ('00600')
  AND  FI1.FT_LVL04_CD IN (8,9,7)
  and  fi1.rec_stat_cd = '01'
  AND  IS2.SKU_NBR = PM2.SKU_NBR
  AND  IS2.SKU_NBR = VA1.SKU_NBR
  AND  PM2.SKU_NBR = VA1.SKU_NBR
  AND  IS2.VNDR_NBR = VA1.VNDR_NBR
  AND  IS2.ITM_NBR = FI1.ITM_NBR
  and  va1.art_nbr_id_cd = upctyp.upc_typ
--  AND  VA1.BAS_ARL_FL = 'B'
  AND  FI1.EFF_FR_DT <= CURRENT DATE
  AND  FI1.EFF_TO_DT > CURRENT DATE
  FETCH FIRST 1000 ROWS ONLY
WITH  UR;