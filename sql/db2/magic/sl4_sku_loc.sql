select *
  from prd.sl4_sku_loc ssl 
 where sku_nbr = '43425617'
 --where loc_nbr = 11674
  with ur
  ;
  
select *
  from accp.sl4_sku_loc ssl 
 where rec_stat_cd not in ('01','40','70','99')
  with ur
  ;

select count(*) as cnt
  from prd.sl4_sku_loc
  with ur;

select *
  from accp.sl4_sku_loc sl4
 where sku_nbr = '00854016'
   and loc_nbr = '50887'
  with ur;
