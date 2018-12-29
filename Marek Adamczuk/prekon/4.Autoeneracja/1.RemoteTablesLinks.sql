create database AutoGen
GO
use AutoGen;

CREATE TABLE dbo.RemoteDBs (
  LogicalDbName sysname,
  PhysicalDbName sysname,
  LocalObjectPrefix nvarchar(100),
  PRIMARY KEY (LogicalDbName)
  )
GO
CREATE TABLE dbo.RemoteTables (
  LogicalDBName sysname,
  RemoteTableName sysname,
  RemoteSchemaName sysname,
  PRIMARY KEY (LogicalDbName,RemoteTableName,RemoteSchemaName)
  );
GO
IF OBJECT_ID('dbo.getRemoteTableLink') IS NOT NULL DROP FUNCTION dbo.getRemoteTableLink;
GO
CREATE FUNCTION dbo.getRemoteTableLink(@LogicalDbName sysname, @RemoteTableName sysname, @RemoteSchemaName sysname)
RETURNS @t TABLE (line nvarchar(max), id int identity primary key)
AS
BEGIN
  DECLARE @LocalObjectName nvarchar(100), @PhysicalDbName sysname;
  SELECT 
    @LocalObjectName = db.LocalObjectPrefix + @RemoteTableName,
    @PhysicalDbName = db.PhysicalDbName
  FROM dbo.RemoteDBs db WHERE db.LogicalDbName = @LogicalDbName;
  INSERT INTO @t (line) SELECT 'CREATE VIEW dbo.'+QUOTENAME(@LocalObjectName);
  INSERT INTO @t (line) SELECT 'AS -- obiekt autogenerowany. Zmiany mog¹ zostaæ utracone w ka¿dej chwili!' 
  INSERT INTO @t (line) SELECT 'SELECT * FROM '+@PhysicalDbName+'.'+QUOTENAME(@RemoteSchemaName)+'.'
  +QUOTENAME(@RemoteTableName)+' WITH (NOLOCK);';
  RETURN;
END;
GO
INSERT INTO dbo.RemoteDBs (LogicalDbName,PhysicalDbName,LocalObjectPrefix)
SELECT 'ADW_SALES','AdventureWorks2012','advsales_';
GO
INSERT INTO dbo.RemoteTables(LogicalDBName,RemoteTableName,RemoteSchemaName)
SELECT 'ADW_SALES',t.name,s.name
FROM AdventureWorks2012.sys.tables t
JOIN AdventureWorks2012.sys.schemas s on t.schema_id = s.schema_id
WHERE s.name = 'Sales'
GO
if object_id('dbo.rebuildRemoteTableLink') is not null drop procedure dbo.rebuildRemoteTableLink;
GO
create procedure dbo.rebuildRemoteTableLink 
@LogicalDbName sysname, 
@RemoteTableName sysname, 
@RemoteSchemaName sysname
as
begin
  DECLARE @TranCnt int = @@TRANCOUNT;
  DECLARE @SavePoint varchar(40) SET @SavePoint = REPLACE(CONVERT(VARCHAR(36),NEWID()),'-','');
  IF @TranCnt = 0 BEGIN TRAN; 
  SAVE TRAN @SavePoint;
  
  DECLARE @SQL nvarchar(max);
  DECLARE @LocalObjectName nvarchar(100);
  SELECT 
    @LocalObjectName = db.LocalObjectPrefix + @RemoteTableName
  FROM dbo.RemoteDBs db WHERE db.LogicalDbName = @LogicalDbName;

  SELECT @SQL = 'IF OBJECT_ID('+quotename(@LocalObjectName,'''')+') IS NOT NULL DROP VIEW dbo.'
  +quotename(@LocalObjectName)+';';
  IF @@ERROR <> 0 GOTO END_ROLLBACK;  

  EXEC (@SQL);
  IF @@ERROR <> 0 GOTO END_ROLLBACK;  
  
  SET @SQL = N'';
  SELECT TOP 99999999999999 @SQL = @SQL+l.line+char(13)+char(10)
  FROM dbo.getRemoteTableLink(@LogicalDbName,@RemoteTableName,@RemoteSchemaName) l 
  ORDER BY l.id;
  IF @@ERROR <> 0 GOTO END_ROLLBACK;  

  EXEC (@SQL);
  IF @@ERROR <> 0 GOTO END_ROLLBACK;  

  IF @TranCnt = 0 AND @@TRANCOUNT > 0 COMMIT TRAN;
  RETURN 0;
  END_ROLLBACK:
  IF @@TRANCOUNT > 0 ROLLBACK TRAN @SavePoint;
  IF @TranCnt = 0 AND @@TRANCOUNT > 0 ROLLBACK TRAN;
  RETURN -1; 
end;
GO

select l.line from RemoteTables t
cross apply getRemoteTableLink(t.LogicalDbName,t.RemoteTableName,t.RemoteSchemaName) l
order by t.RemoteTableName, t.RemoteSchemaName, l.id;


exec dbo.rebuildRemoteTableLink  'ADW_SALES','Currency','Sales'
GO
exec sp_helptext advsales_Currency
GO
if object_id('dbo.rebuildRemoteDb') is not null drop procedure dbo.rebuildRemoteDb;
GO
create procedure dbo.rebuildRemoteDb @LogicalDbName sysname
as
begin
  DECLARE @TranCnt int = @@TRANCOUNT;
  DECLARE @SavePoint varchar(40) SET @SavePoint = REPLACE(CONVERT(VARCHAR(36),NEWID()),'-','');
  IF @TranCnt = 0 BEGIN TRAN; 
  SAVE TRAN @SavePoint;
  
  DECLARE @RemoteTableName sysname, @RemoteSchemaName sysname, @Result int = 0;
  DECLARE c CURSOR LOCAL FAST_FORWARD FOR 
  SELECT r.RemoteTableName, r.RemoteSchemaName 
  FROM dbo.RemoteTables r WHERE r.LogicalDBName = @LogicalDbName

  OPEN c;
  FETCH NEXT FROM c into @RemoteTableName, @RemoteSchemaName;
  WHILE @@fetch_status = 0 BEGIN
    EXEC @Result = dbo.rebuildRemoteTableLink @LogicalDbName, @RemoteTableName, @RemoteSchemaName;
    FETCH NEXT FROM c into @RemoteTableName, @RemoteSchemaName;
  END;
  CLOSE c; DEALLOCATE c;

  IF @TranCnt = 0 AND @@TRANCOUNT > 0 COMMIT TRAN;
  RETURN 0;
  END_ROLLBACK:
  IF @@TRANCOUNT > 0 ROLLBACK TRAN @SavePoint;
  IF @TranCnt = 0 AND @@TRANCOUNT > 0 ROLLBACK TRAN;
  RETURN -1; 
end;
GO
exec dbo.rebuildRemoteDb 'ADW_SALES';
GO
delete from RemoteTables where RemoteTableName = 'Store'
GO
select * From sys.views v where v.name like 'advsales_%'


advsales_CountryRegionCurrency
advsales_CreditCard
advsales_Currency
advsales_CurrencyRate
sp_helptext advsales_Customer
advsales_PersonCreditCard
advsales_SalesOrderDetail
advsales_SalesOrderHeader
advsales_SalesOrderHeaderSalesReason
