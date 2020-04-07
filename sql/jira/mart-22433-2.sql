with rownums (cnt) as (
select 1 as cnt
  from accp.TT1_TRUTH_TBL
 union all
select cnt + 1
  from rownums
 where cnt < 999
)
select substr(digits(cnt),8,3) as keyv
      ,'50' as val
  from rownums
;