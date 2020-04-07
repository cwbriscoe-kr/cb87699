WITH VALIDSKUS AS (                                        
SELECT SL4.SKU_NBR AS SKU                                  
  FROM PRD.SL4_SKU_LOC  SL4                                    
      ,PRD.VD1_VNDR_DTL VD1                                    
 WHERE SL4.LOC_NBR            = '00300'                    
   AND SL4.REC_STAT_CD        = '01'                       
   AND SL4.PRMY_SRCE_NBR      = VD1.VNDR_NBR               
   AND VD1.VND_ONE_TIME_VEND  = 'V'                        
   AND NOT EXISTS (                                        
       SELECT 1                                            
         FROM PRD.SL4_SKU_LOC S                                
        WHERE S.LOC_NBR      != '00300'                    
          AND S.SKU_NBR       = SL4.SKU_NBR                
          AND S.PRMY_SRCE_NBR = SL4.PRMY_SRCE_NBR          
        FETCH FIRST 1 ROW ONLY                             
       )                                                   
), CURRTEMPS AS (                                          
SELECT CHNG_NBR                                            
      ,SKU_NBR                                             
  FROM PRD.PP1_MDSE_PRC_PND                                    
      ,VALIDSKUS                                           
 WHERE SKU_NBR       = VALIDSKUS.SKU                       
   AND LOC_NBR       = '00300'                             
   AND PERM_TEMP_IND = 'T'                                 
), MODELTEMPS AS (                                         
SELECT P.CHNG_NBR                                          
      ,P.SKU_NBR                                           
      ,C.CHNG_NBR AS MISSING                               
  FROM VALIDSKUS                                           
      ,PRD.PP1_MDSE_PRC_PND P                                  
  LEFT OUTER JOIN CURRTEMPS C                              
    ON (P.CHNG_NBR = C.CHNG_NBR AND P.SKU_NBR = C.SKU_NBR) 
 WHERE P.SKU_NBR       = VALIDSKUS.SKU                     
   AND P.LOC_NBR       = '00035'                           
   AND P.PERM_TEMP_IND = 'T'                               
   AND P.STAT_IND IN ('Z','L','A')                         
   AND P.PRC_TYP_CD IN                                     
       ('10','11','12','13','14','15','55'                 
       ,'60','61','62','63','80','82','89')                
   AND C.CHNG_NBR IS NULL                                  
), MISSING AS (                                            
SELECT *                                                   
  FROM MODELTEMPS M                                        
 WHERE NOT EXISTS (                                        
       SELECT 1                                            
         FROM PRD.SO1_PRC_SKU_OVR S                            
        WHERE S.CHNG_NBR  = M.CHNG_NBR                     
          AND S.SKU_NBR   = M.SKU_NBR                      
          AND S.LOC_NBR   = '00300'                        
          AND S.XCLD_FLG  = 'X'                            
        FETCH FIRST 1 ROW ONLY                             
       )                                                   
)                
SELECT PP1.SKU_NBR                               
      ,'00300' AS LOC_NBR                        
      ,MAX(PP1.EFF_FR_DT, CURRENT DATE + 1 DAY)   
      ,CD4.EFF_TO_DT                             
      ,PP1.CHNG_NBR                              
      ,PP1.PERM_TEMP_IND                         
      ,PP1.PRC_TYP_CD                            
      ,PP1.ADJ_PRC_AMT                           
      ,PP1.ADJ_PRC_PCT                           
      ,PP1.FIX_UNT_PRC_AMT                       
      ,PP1.N_FOR_QTY                             
      ,PP1.N_FOR_PRC_AMT                         
      ,PP1.PRC_MTHD_CD                           
      ,PP1.PRTY_CD                               
      ,PP1.POS_IND                               
      ,'A' AS STAT_IND                           
      ,CURRENT DATE AS REC_CRT_DT                
      ,CURRENT TIMESTAMP AS REC_ALT_TS           
      ,'300AUDIT' AS OPER_ID                     
      ,PP1.GRP_IND                               
  FROM PRD.PP1_MDSE_PRC_PND PP1                      
      ,PRD.CD4_CHNG_DFLT CD4                         
      ,MISSING                                   
 WHERE PP1.CHNG_NBR = MISSING.CHNG_NBR           
   AND PP1.SKU_NBR  = MISSING.SKU_NBR            
   AND PP1.LOC_NBR  = '00035'                    
   AND PP1.CHNG_NBR = CD4.CHNG_NBR   
   AND CD4.EFF_TO_DT > MAX(PP1.EFF_FR_DT, CURRENT DATE + 1 DAY)            
 ORDER BY PP1.CHNG_NBR, PP1.SKU_NBR              
  with ur
  ;                                          