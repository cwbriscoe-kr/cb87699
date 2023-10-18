-- remove logical file
alter database XXXXX 
  remove file (NAME = FG_SMY_P03);
go

-- remove logical filegroup
alter database XXXXX 
  remove filegroup (NAME = FG_SMY_P03);
go