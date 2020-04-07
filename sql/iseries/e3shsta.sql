select e3sfmi.e3shsta.*
  from e3sfmi.e3shsta
 where hayear = 2013
   and substr(hastor,1,2) != 'VS'
   and ha701 > 20
   and hatype = 'F'
 fetch first 100 rows only
