select iitem
      ,istor
      ,ipres
      ,e3sfmi.e3sitm.*
from e3sfmi.e3sitm
 where iitem  = '00854016'
   and istor = '00614'
  with ur;
