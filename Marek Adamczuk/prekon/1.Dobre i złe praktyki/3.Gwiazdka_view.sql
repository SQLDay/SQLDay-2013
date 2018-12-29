-------------------------------------
--Zmiana nazwy obiektu proceduralnego
--"Gwiazdka"
-------------------------------------
USE master;
GO
IF DB_ID('TestDb') IS NOT NULL
  ALTER DATABASE TestDb SET READ_ONLY WITH ROLLBACK IMMEDIATE;
GO
DROP DATABASE TestDb;
GO
CREATE DATABASE TestDb;
GO
USE TestDb;
GO

--Prosta tabela, 10 rekordów ...
CREATE TABLE dbo.MyTable (ID int IDENTITY(1,1) NOT NULL);
GO
INSERT INTO dbo.MyTable DEFAULT VALUES;
GO 10

--... i widok na niej
CREATE VIEW dbo.vMyView 
AS 
SELECT * FROM dbo.MyTable;
GO

--Test
SELECT * FROM dbo.vMyView;
GO

--Dodanie kolumny
ALTER TABLE dbo.MyTable ADD NewColumn varchar(10) NULL;
GO

--Test - coœ s³abo z t¹ gwiazdk¹!
SELECT * FROM dbo.vMyView;
GO

--Naprawiamy
EXEC sp_refreshsqlmodule 'dbo.vMyView';
GO

--Test
SELECT * FROM dbo.vMyView;
GO

-- Best practice: zawsze naprawiamy przy dodaniu kolumny
IF EXISTS (SELECT * FROM sys.triggers 
  WHERE name = 'DDLTR_AUTO_REFRESH_DEP_VIEWS'
)
  DROP TRIGGER DDLTR_AUTO_REFRESH_DEP_VIEWS ON DATABASE;
GO
CREATE TRIGGER DDLTR_AUTO_REFRESH_DEP_VIEWS
ON DATABASE 
FOR ALTER_TABLE
AS
BEGIN
 DECLARE @E xml = EVENTDATA();
 DECLARE 
    @RefObject nvarchar(512),
    @ObjectName sysname, 
    @SchemaName sysname, 
    @SQLCommand nvarchar(max),
    @id int;
 SELECT
 @ObjectName =    @E.value('(/EVENT_INSTANCE/ObjectName)[1]','nvarchar(128)'),
 @SchemaName =    @E.value('(/EVENT_INSTANCE/SchemaName)[1]','nvarchar(128)'),
 @SQLCommand = @E.value('(/EVENT_INSTANCE/TSQLCommand)[1]','nvarchar(max)');  
 
 SELECT @id = OBJECT_ID(QUOTENAME(@SchemaName)+'.'+QUOTENAME(@ObjectName))

  IF @SQLCommand NOT LIKE N'%Don''t refresh views!%' 
  BEGIN
    DECLARE c CURSOR LOCAL STATIC READ_ONLY FORWARD_ONLY FOR  

    -- obiekty zale¿ne, które wykonuj¹ SELECT * na naszej tabeli
    SELECT QUOTENAME(SCHEMA_NAME(o.schema_id))+'.'+QUOTENAME(o.name)
    FROM sys.sql_dependencies AS d
    JOIN sys.objects AS o ON d.object_id = o.object_id   
      WHERE d.referenced_major_id = @id 
      AND d.is_select_all = 1 
      AND o.type IN ('V','IF');

    OPEN c;
    FETCH NEXT FROM c INTO @RefObject;
    WHILE @@FETCH_STATUS = 0 BEGIN
      FETCH NEXT FROM c INTO @RefObject;
      EXEC sys.sp_refreshsqlmodule @RefObject;
    END;
    CLOSE c; DEALLOCATE c;
  END;
END;
GO

-- Testy
ALTER TABLE dbo.MyTable ADD OneMoreColumn varchar(10) NULL;
GO
SELECT * FROM dbo.vMyView;
GO

-- Widok z problemami. Zawiera kolumnê, któr¹ zechcemy dodaæ do tabeli
CREATE VIEW dbo.vNewView
AS
SELECT *, CONVERT(int, 1) AS YetAnotherOne FROM dbo.MyTable;
GO

ALTER TABLE dbo.MyTable ADD YetAnotherOne varchar(10) NULL;
GO

ALTER TABLE dbo.MyTable ADD YetAnotherOne varchar(10) NULL; 
  -- Don't refresh views!
GO

-- cleanup
IF OBJECT_ID('dbo.vNewView') IS NOT NULL
   DROP VIEW dbo.vNewView;
GO



