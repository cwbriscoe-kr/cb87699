with valid as (
select substr(itm_no,1,8) as sku
,CASE 
 WHEN COALESCE(( 
   SELECT 1 
     FROM accp.PID_ORDEN ORD 
    WHERE ORD.CAS_UPC_NO      = CA.CAS_UPC_NO 
      AND ORD.BIL_DIV_NO     != '701' 
      AND ORD.DIV_CAS_STU_CD != 'D' 
    FETCH FIRST 1 ROWS ONLY),0) = 1 
 THEN 
   'Y' 
 WHEN COALESCE(( 
   SELECT 1 
     FROM accp.PID_DSDIT DSD 
    WHERE DSD.CAS_UPC_NO  = CA.CAS_UPC_NO 
      AND DSD.BIL_STU_CD != '03' 
    FETCH FIRST 1 ROWS ONLY),0) = 1 
 THEN 
   'Y' 
 ELSE 
   'N' 
 END                                     AS NON_FM_KMA_FL
from accp.pid_whsca ca
where src_id = '791'
)
select * from valid where non_fm_kma_fl = 'N' fetch first 100 rows only;
