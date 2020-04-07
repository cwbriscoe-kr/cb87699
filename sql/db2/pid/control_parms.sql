select *
  from accp.jp1_job_parm
 where job_nm = 'UACPID00'
;

/*
DEBUG-LOGGING              
ROLLBACK                   
AUTO-RESTART               
ALLOW-AUDIT                
AUDIT-WRAP                 
RESTART-INT                
ABEND-INT                  
PROC-CHUNK-SZ              
AUDIT-CHUNK-SZ             
REC-CMTFREQ          
UPDT-CMTFREQ 
*/
update accp.jp1_job_parm
   set parm_txt          = 'Y N Y N N 005 015 999 999 50 10'
 where job_nm            = 'UACPID00'
   and pgm_nm            = 'CONTROL' 
;                           