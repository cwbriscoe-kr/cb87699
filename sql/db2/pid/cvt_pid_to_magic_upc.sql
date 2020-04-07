with bupc as (
  select '1084467700025' as bupc
    from prd.tt1_truth_tbl
),
gupc as (
  select substr(bupc,1,1)||substr(bupc,3,1)
       ||substr(bupc,2,1)||substr(bupc,4,10) as gupc
    from bupc
),
chkdgt1 as (
  select cast (substr(gupc,1,1) as integer) as d1
        ,cast (substr(gupc,2,1) as integer) as d2
        ,cast (substr(gupc,3,1) as integer) as d3
        ,cast (substr(gupc,4,1) as integer) as d4
        ,cast (substr(gupc,5,1) as integer) as d5
        ,cast (substr(gupc,6,1) as integer) as d6
        ,cast (substr(gupc,7,1) as integer) as d7
        ,cast (substr(gupc,8,1) as integer) as d8
        ,cast (substr(gupc,9,1) as integer) as d9
        ,cast (substr(gupc,10,1) as integer) as d10
        ,cast (substr(gupc,11,1) as integer) as d11
        ,cast (substr(gupc,12,1) as integer) as d12
        ,cast (substr(gupc,13,1) as integer) as d13
    from gupc
),
chkdgt2 as (
  select d1*3+d2*1+d3*3+d4*1+d5*3+d6*1+d7*3
        +d8*1+d9*3+d10*1+d11*3+d12*1+d13*3  as chksum
    from chkdgt1
),
chkdgt3 as (
  select ((chksum/10)*10+10) - chksum as digit
    from chkdgt2
),
chkdgt as (
  select case
           when digit = 10 then
             '0'
           else
             substr(digits(digit),10,1)
         end as chkdgt 
    from chkdgt3
),
magupc as (
  select (select gupc from gupc)||(select chkdgt from chkdgt)
      as magupc
    from prd.tt1_truth_tbl
)
select * from magupc;
