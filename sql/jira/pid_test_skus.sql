SELECT IS2.SKU_NBR                      
  FROM  ACCP.IS2_ITM_SKU IS2            
       ,ACCP.VA1_VNDR_ART VA1           
WHERE NOT EXISTS (                      
       SELECT 1                         
         FROM ACCP.SL4_SKU_LOC SL4      
        WHERE SL4.SKU_NBR = IS2.SKU_NBR 
          AND LOC_NBR = 461         
       )                                
   AND IS2.REC_STAT_CD = '30'           
   AND IS2.SKU_TYP_CD = '01'            
   AND VA1.SKU_NBR = IS2.SKU_NBR        
   AND VA1.BAS_ARL_FL = 'B'             
   AND VA1.ART_NBR_ID_CD = 'UA'         
FETCH FIRST 50 ROWS ONLY                
  WITH UR;                              