SELECT *                             
FROM ACCP.PID_TECCODES                    
WHERE TBL_NAM_ID = '0041'            
  AND TBL_OWN_ID = '000' 
--  AND GNC_EFF_DT <= CURRENT DATE            
--  AND GNC_EFF_DT <= '2012-06-27'  - current date   
  AND KEY_VLU_CD = '02663'              -- message code
;

SELECT KEY_VLU_CD AS CPT_DPT_CD
      ,CASE SUBSTR(GNC_TX,27,1) 
       WHEN 'E' THEN
         'Y'
       ELSE
         'N'
       END AS CORP_CNTL_FL
FROM ACCP.PID_TECCODES 
WHERE TBL_NAM_ID = '0295'
  AND TBL_OWN_ID = '000'
  AND (GNC_TX LIKE '__________________________Y%' 
   OR  GNC_TX LIKE '__________________________C%' 
   OR  GNC_TX LIKE '__________________________E%' 
   OR  GNC_TX LIKE '__________________________S%')
;

SELECT distinct(substr(gnc_tx,27,1)) as code
      ,t295.*                             
FROM ACCP.PID_TECCODES     t295               
WHERE TBL_NAM_ID = '0370'            
  AND TBL_OWN_ID = '000' 
--  and gnc_eff_dt <= current date
;

SELECT distinct(substr(key_vlu_cd,1,2)) as code                             
FROM ACCP.PID_TECCODES     t295               
WHERE TBL_NAM_ID = '0370'            
  AND TBL_OWN_ID = '000' 
  and gnc_eff_dt <= current date
;