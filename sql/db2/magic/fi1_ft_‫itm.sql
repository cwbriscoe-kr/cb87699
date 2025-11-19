select *
  from fi1_ft_itm ffi
 where ft_lvl09_cd = 456
   and rec_stat_cd = '01'
  with ur
  ;
  
select *
  from fi1_ft_itm ffi
 where itm_nbr = '12782529'
  with ur 
  ;

with items as (
select *
  from fi1_ft_itm
 where dec_itm_nbr in (
05661909,
05661602,
05661695,
05661497,
05661657
     )
   --and rec_stat_cd = '01'
)
select is2.*
  from is2_itm_sku is2
      ,items it
 where is2.itm_nbr = it.itm_nbr
  with ur
;

select *
  from fi1_ft_itm
    where dec_itm_nbr = 13731687
        and rec_stat_cd = '01'
    with ur;