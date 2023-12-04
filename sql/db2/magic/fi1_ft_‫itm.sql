select *
  from prd.fi1_ft_itm ffi 
 where ft_lvl09_cd = 456
   and rec_stat_cd = '01'
  with ur
  ;
  
select *
  from accp.fi1_ft_itm ffi 
 where itm_nbr = '12782529'
  with ur 
  ;