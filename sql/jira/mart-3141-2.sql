SELECT DISTINCT(PP1.SKU_NBR)
  FROM PRD.PP1_MDSE_PRC_PND PP1
      ,PRD.RS6_RPLN_SKU     RS6
 WHERE PP1.PERM_TEMP_IND = 'P'
   AND PP1.SKU_NBR = RS6.SKU_NBR
   AND RS6.SKU_RPLN_MTHD_CD = 'B'
  ;

WITH INPUT AS (
  SELECT
--         '10037041' AS SKU
         '02079448' AS SKU
        ,'00135'    AS LOC
    FROM PRD.TT1_TRUTH_TBL
), CURRENT AS (
  SELECT '1' AS SORT
        ,PM2.EFF_FR_DT AS AD_BEG_DT            
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
        ,'P' AS TYPE                     
    FROM PRD.RS5_RPLN_SKL RS5                  
        ,PRD.PM2_MDSE_PRC_MSTR PM2             
        ,PRD.VA1_VNDR_ART VA1   
        ,INPUT               
   WHERE RS5.SKU_NBR = PM2.SKU_NBR             
     AND RS5.SKL_GRP_CD = PM2.LOC_NBR          
     AND RS5.SKU_NBR = VA1.SKU_NBR             
     AND VA1.BAS_ARL_FL = 'B'   
     AND PM2.SKU_NBR = INPUT.SKU
     --AND PM2.LOC_NBR = INPUT.LOC
 ), FUTURE AS (
   SELECT '2' AS SORT
        ,PP1.EFF_FR_DT AS AD_BEG_DT            
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
        ,PP1.PERM_TEMP_IND AS TYPE               
    FROM PRD.RS5_RPLN_SKL RS5                  
        ,PRD.PP1_MDSE_PRC_PND PP1            
        ,PRD.VA1_VNDR_ART VA1   
        ,INPUT               
   WHERE RS5.SKU_NBR = PP1.SKU_NBR             
     AND RS5.SKL_GRP_CD = PP1.LOC_NBR        
     AND RS5.SKU_NBR = VA1.SKU_NBR      
     AND RS5.SKL_RPLN_MTHD_CD IN ('I','B','S')       
     AND VA1.BAS_ARL_FL = 'B'   
     AND PP1.STAT_IND IN ('A','L')
     AND PP1.EFF_FR_DT >= CURRENT DATE
     AND PP1.FIX_UNT_PRC_AMT > 0   
     AND PP1.SKU_NBR = INPUT.SKU
     --AND PP1.LOC_NBR = INPUT.LOC 
), DATA AS (
  SELECT * FROM CURRENT
   UNION 
  SELECT * FROM FUTURE
)
 SELECT * 
   FROM DATA        
  ORDER BY SKU_NBR, LOC_ID, SORT, AD_BEG_DT, AD_END_DT, CUR_PRC DESC       
   WITH UR                                    
;                                            