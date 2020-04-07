  select * 
    from SYS.ALL_OBJECTS 
   where OBJECT_TYPE = 'FUNCTION'
order by OWNER, OBJECT_NAME;