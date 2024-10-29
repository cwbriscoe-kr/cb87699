select sku_nbr
      ,prmy_srce_nbr
      ,count(*) as loc_cnt
  from prd.sl4_sku_loc
 where mdse_flow_cd = 'WHP'
   and loc_nbr like '50%'
   and rec_stat_cd = '01'
 group by sku_nbr, prmy_srce_nbr
  with ur;