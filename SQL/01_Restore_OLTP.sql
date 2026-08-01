USE [master];
GO

IF DB_ID('AdventureWorks-OLTP') IS NOT NULL
BEGIN
    ALTER DATABASE [AdventureWorks-OLTP] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [AdventureWorks-OLTP];
END
GO

RESTORE DATABASE [AdventureWorks-OLTP]
FROM DISK = N'E:\Ejada Project\Project''26\Project''26\AdventureWorks-OLTP\AdventureWorks-OLTP\AdventureWorks-OLTP.bak'
WITH MOVE N'AdventureWorks2012' TO N'E:\Ejada Project\Claude_Auto_Project\Data\AdventureWorks-OLTP.mdf',
     MOVE N'AdventureWorks2012_log' TO N'E:\Ejada Project\Claude_Auto_Project\Data\AdventureWorks-OLTP_log.ldf',
     REPLACE,
     STATS = 10;
GO
