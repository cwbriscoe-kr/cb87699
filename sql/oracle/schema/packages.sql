  select * 
    from SYS.ALL_OBJECTS 
   where OBJECT_TYPE = 'PACKAGE' 
order by OWNER, OBJECT_NAME;