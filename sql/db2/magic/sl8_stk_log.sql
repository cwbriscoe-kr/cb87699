select *
  from prd.SL8_STK_LOG ssl
 where sku_nbr = '36961016'
   and loc_nbr = '00225'
  with ur
  ;
  
select sku_nbr
      ,loc_nbr
      ,STK_TXN_CD
      ,IAS_REAS_CD
      ,sum(ext_rtl_amt) as sum_ext_rtl_amt
  from prd.sl8_stk_log
 where sku_nbr = '81620111'
   and loc_nbr = '00685'
group by sku_nbr, loc_nbr, STK_TXN_CD, IAS_REAS_CD
order by sku_nbr, loc_nbr, STK_TXN_CD, IAS_REAS_CD 
    with ur
  ;

-- 36961016  00225
-- 81620111  00685