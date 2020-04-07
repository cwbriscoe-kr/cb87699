WITH PRICES AS (
SELECT PM2.EFF_FR_DT AS AD_BEG_DT            
      ,PM2.EFF_TO_DT AS AD_END_DT            
      ,SUBSTR(CHAR(DIGITS(DECIMAL(RTRIM(     
       VA1.ART_NBR),14))),1,13) AS CON_UPC_NO
      ,RS5.SKL_GRP_CD AS LOC_ID              
      ,DIGITS(CASE                           
       WHEN PM2.TEMP_UNT_PRC_AMT > 0 THEN    
         PM2.TEMP_UNT_PRC_AMT                
       ELSE                                  
         PM2.FIX_UNT_PRC_AMT                 
       END) AS CUR_PRC    
      ,DIGITS(FIX_UNT_PRC_AMT) AS PERM_PRC
      ,PM2.SKU_NBR AS SKU_NBR
      ,'P' AS PRC_TYP                   
  FROM prd.RS5_RPLN_SKL RS5                  
      ,prd.PM2_MDSE_PRC_MSTR PM2             
      ,prd.VA1_VNDR_ART VA1                  
 WHERE RS5.SKU_NBR = PM2.SKU_NBR             
   AND RS5.SKL_GRP_CD = PM2.LOC_NBR      
   AND RS5.SKU_NBR = VA1.SKU_NBR     
   AND RS5.SKL_RPLN_MTHD_CD IN ('I','B','S')         
   AND VA1.BAS_ARL_FL = 'B'                                               
UNION                 
SELECT PP1.EFF_FR_DT AS AD_BEG_DT            
      ,PP1.EFF_TO_DT AS AD_END_DT            
      ,SUBSTR(CHAR(DIGITS(DECIMAL(RTRIM(     
       VA1.ART_NBR),14))),1,13) AS CON_UPC_NO
      ,RS5.SKL_GRP_CD AS LOC_ID              
      ,DIGITS(PP1.FIX_UNT_PRC_AMT) AS CUR_PRC   
      ,CASE PP1.PERM_TEMP_IND
       WHEN 'P' THEN
         DIGITS(PP1.FIX_UNT_PRC_AMT)
       ELSE
         '0000000' 
       END AS PERM_PRC            
      ,PP1.SKU_NBR AS SKU_NBR   
      ,PP1.PERM_TEMP_IND AS PRC_TYP               
  FROM prd.RS5_RPLN_SKL RS5                  
      ,prd.PP1_MDSE_PRC_PND PP1            
      ,prd.VA1_VNDR_ART VA1                  
 WHERE RS5.SKU_NBR = PP1.SKU_NBR             
   AND RS5.SKL_GRP_CD = PP1.LOC_NBR        
   AND RS5.SKU_NBR = VA1.SKU_NBR      
   AND RS5.SKL_RPLN_MTHD_CD IN ('I','B','S')       
   AND VA1.BAS_ARL_FL = 'B'   
   AND PP1.STAT_IND IN ('A','L')
   AND PP1.EFF_FR_DT >= CURRENT DATE
   AND PP1.FIX_UNT_PRC_AMT > 0          
), GROUPINGS AS (
SELECT CON_UPC_NO
      ,LOC_ID
      ,COUNT(*) AS CNT
  FROM PRICES
 GROUP BY CON_UPC_NO, LOC_ID
), DATA AS (
SELECT P.*
      ,G.CNT
      ,p.AD_BEG_DT - 1 DAY AS DAY_BEFORE
      ,CASE P.AD_END_DT
       WHEN '9999-12-31' THEN
         '9999-12-31'
       ELSE
         P.AD_END_DT + 1 DAY
       END AS DAY_AFTER
 FROM PRICES P
     ,GROUPINGS G
WHERE P.CON_UPC_NO = G.CON_UPC_NO
  AND P.LOC_ID = G.LOC_ID
)
SELECT *
  FROM DATA
-- WHERE SKU_NBR IN ('01136142','01292411','01367911','01396843','01403817')
--   AND LOC_ID = '00005'
 ORDER BY CON_UPC_NO, LOC_ID, AD_BEG_DT
  WITH UR                                 
;     

select pp1.*
  FROM prd.PP1_MDSE_PRC_PND pp1
      ,prd.RS5_RPLN_SKL rs5
 where rs5.sku_nbr = pp1.sku_nbr
   and rs5.skl_grp_cd = pp1.loc_nbr
   --and rs5.sku_nbr in ('01127713', '01256116', '01265118')
   and rs5.skl_grp_cd = '00005'
   and pp1.stat_ind in ('A','L')
   and pp1.eff_fr_dt >= current date
   and perm_temp_ind = 'P'
   ;

select *
  FROM prd.PM2_MDSE_PRC_MSTR
-- where sku_nbr in ('01127713', '01256116', '01265118')
 WHERE loc_nbr = '00065'
   --and stat_ind in ('A','L')
   --and eff_fr_dt >= current date
 ;
   ;