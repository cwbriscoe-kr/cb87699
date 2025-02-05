select iitem
      ,istor
      ,ioh2nd as facings
      ,isize2 as capacity
      ,e3sfmi.e3sitm.*
from e3sfmi.e3sitm
 where iitem  = '08139214'
   and istor = '40094'
  with ur;

set e3sitm.isize2 = :hCapacity
   ,e3sitm.ioh2nd = :hFacings
