alter database CKB_prdcopy set OFFLINE;
go

alter database CKB_prdcopy
  modify file (NAME = CKB_prdcopy,
               FILENAME = 'G:\MSSQL13.SQL1\MSSQL\DATA\CKB_prdcopy.mdf');
go

alter database CKB_prdcopy
  modify file (NAME = CKB_prdcopy_log,
               FILENAME = 'G:\MSSQL13.SQL1\MSSQL\DATA\CKB_prdcopy_log.ldf');
go

-- Physically copy database files here

alter database CKB_prdcopy set ONLINE;
go
