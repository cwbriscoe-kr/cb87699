WITH DATE AS (
  SELECT CURRENT DATE AS DATE
    FROM PRD.TT1_TRUTH_TBL
), DOW AS (
  SELECT DAYOFWEEK(date) AS VAL
    FROM date
), SUNDAY AS (
  SELECT DATE - (VAL - 1) DAYS AS DATE
    FROM DATE, DOW
)
SELECT SUBSTR(CHAR(DIGITS(DECIMAL(RTRIM(     
       VA1.ART_NBR),14))),1,14) AS LEAD_UPC
      ,IS2.DESC_LNG_TXT
      ,COALESCE((
       SELECT SUM(QTY)
         FROM PRD.OH3_SKC_OH
        WHERE SKU_NBR    = IS2.DEC_SKU_NBR
          AND PERD_FR_DT = DATE
          AND LOC_NBR    < 1000
       ),0) AS BOH_01
      ,COALESCE((
       SELECT SUM(QTY)
         FROM PRD.OH3_SKC_OH
        WHERE SKU_NBR    = IS2.DEC_SKU_NBR
          AND PERD_FR_DT = DATE
          AND (LOC_NBR   >= 1000
           OR  LOC_NBR IN (65,461))
       ),0) AS BOH_91
  FROM PRD.IS2_ITM_SKU  IS2
      ,PRD.VA1_VNDR_ART VA1
      ,SUNDAY
 WHERE IS2.SKU_NBR    = VA1.SKU_NBR
   AND VA1.LD_ART_IND = 'L'
   AND IS2.SKU_NBR    = '00490344'
  WITH UR
;

select va4.corp_vndr_cd
 from prd.VD1_VNDR_DTL    vd1
     ,prd.VA4_VNDR_AP_DTL va4
where vd1.vnd_pay_to_vendor = va4.vndr_nbr
  and vd1.vndr_nbr = '10879650'
  ;

select *
  from prd.SV1_SKU_VNDR_DTL
 where mstr_art_nbr like '%63050944934%'
 ;

select *
  FROM prd.RS5_RPLN_SKL
 where sku_nbr = '03648247'
 ;

select *
  FROM prd.SL4_SKU_LOC
 where sku_nbr = '03648247'
 ;