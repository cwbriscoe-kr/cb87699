select gm1.grp_nbr                                     
      ,gm1.mbr_nbr                                     
      ,ag1.grp_desc                                    
  from prd.ag1_attr_grp  ag1                               
      ,prd.gm1_grp_mbr   gm1                               
 where ag1.grp_co_nbr   = gm1.grp_co_nbr               
   and ag1.grp_rgn_nbr  = gm1.grp_rgn_nbr              
   and ag1.grp_nbr      = gm1.grp_nbr                  
   and ag1.grp_type     = 'L'                          
   and substr(gm1.mbr_nbr,4,5) in                      
                   (select distinct(rs5.skl_grp_cd)    
                      from prd.rs5_rpln_skl rs5            
                     where rs5.skl_rpln_mthd_cd ¬= 'D')
order by gm1.grp_nbr                                     
        ,gm1.mbr_nbr                                     
   for fetch only                                      
  with ur   
  ;