
dbcc clonedatabase(Magic, Magic_Schema) with verify_clonedb;

alter database Magic_Schema set read_write;

backup database Magic_Schema to disk = N'C:\Temp\Magic_Schema_20231012.bak';

drop database Magic_Schema;