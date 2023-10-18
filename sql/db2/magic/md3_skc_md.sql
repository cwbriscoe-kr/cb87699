select *
  from prd.MD3_SKC_MD msm
  with ur;

select perd_fr_dt 
      ,sum(rtl_amt)
  from prd.MD3_SKC_MD msm
 where rtl_amt < 1000000
   and rtl_amt > -1000000
   and perd_fr_dt >= '2023-02-05'
   and MD_REAS_CD = '99'
 group by perd_fr_dt
 order by perd_fr_dt
  with ur
  ;

select sum(rtl_amt)
  from prd.MD3_SKC_MD msm
 where rtl_amt < 1000000
   and rtl_amt > -1000000
   and perd_fr_dt >= '2022-10-09'
   and MD_REAS_CD = '99'
  with ur
  ;
  
