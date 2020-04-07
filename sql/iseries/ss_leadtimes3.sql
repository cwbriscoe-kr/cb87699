select e3lt.ssvnd
         ,e3lt.magvnd
         ,e3lt.e3lt
         ,maglt.maglt
  from e3lt left outer join maglt on e3lt.magvnd = maglt.magvnd
 where cast(e3lt.e3lt as integer) != cast(maglt.maglt as integer);
