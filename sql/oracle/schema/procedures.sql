  select * 
    from SYS.ALL_OBJECTS 
   where OBJECT_TYPE = 'PROCEDURE'
order by OWNER, OBJECT_NAME;