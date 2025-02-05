select iitem
      ,istor
      ,ipres
      ,e3sfmi.e3sitm.*
from e3sfmi.e3sitm
 where iitem  = '08139214'
   and istor = '40475'
  with ur;
