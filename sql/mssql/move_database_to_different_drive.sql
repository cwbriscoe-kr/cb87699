alter database TEST
  modify file (NAME = TEST,
               FILENAME = 'G:\MSSQL13.SQL1\MSSQL\DATA\TEST.mdf');
go

alter database TEST
  modify file (NAME = TEST_log,
               FILENAME = 'G:\MSSQL13.SQL1\MSSQL\DATA\TEST_log.ldf');
go

alter database TEST set OFFLINE;
go

-- Physically copy database files here

alter database TEST set ONLINE;
go

