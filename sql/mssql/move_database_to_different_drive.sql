alter database MPR
  modify file (NAME = MPR,
               FILENAME = 'G:\MSSQL13.SQL1\MSSQL\DATA\MPR.mdf');
go

alter database MPR
  modify file (NAME = MPR_log,
               FILENAME = 'G:\MSSQL13.SQL1\MSSQL\DATA\MPR_log.ldf');
go

alter database MPR set OFFLINE;
go

-- Physically copy database files here

alter database MPR set ONLINE;
go

