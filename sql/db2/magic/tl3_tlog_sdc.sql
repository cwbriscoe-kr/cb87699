select count(*)
  from prd.tl3_tlog_sdc tts 
 where bus_dt < '2023-04-01'
   and loc_nbr = 460
  with ur
  ;