SELECT rmdat.runtime.*
      ,timestampdiff(4, cast(finish - start as char(22))) as DIFF_IN_MINUTES
 FROM RMDAT.RUNTIME  
WHERE YEAR(DATE) = 2013      
  AND SYS = 'ASR'
ORDER BY DATE DESC