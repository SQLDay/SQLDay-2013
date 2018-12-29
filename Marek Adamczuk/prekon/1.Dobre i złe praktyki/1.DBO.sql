--------------------------------------------
--"DBO"
--------------------------------------------

USE master;
GO
IF DB_ID('TestDb') IS NOT NULL BEGIN
  ALTER DATABASE TestDb SET READ_ONLY WITH ROLLBACK IMMEDIATE;
  DROP DATABASE TestDb;
END;
GO
CREATE DATABASE TestDb;
GO
USE TestDb;
GO

--Nowy user. Wa¿ne, tak za³o¿ony ma swój schemat!
GO
EXEC sp_adduser 'Weak';
GO

--Procedura-leñ - nic nie robi :-)
IF OBJECT_ID('dbo.usp_Fake', 'P') IS NOT NULL
  DROP PROC dbo.usp_Fake;
GO  
CREATE PROC dbo.usp_Fake
AS;
GO

--Nadajemy uprawnienia
GRANT EXECUTE ON OBJECT::dbo.usp_Fake TO Weak;
GO

--Test - bez dbo
EXECUTE AS USER = 'Weak';
DECLARE @t datetime2(7) = SYSDATETIME();
DECLARE @i int = 1;
WHILE @i <= 500000
BEGIN
  EXEC usp_Fake; 
  SET @i = @i + 1;
END;
SELECT DATEDIFF(ms, @t, SYSDATETIME()) milisekund;
REVERT;
GO

--Test - z dbo
EXECUTE AS USER = 'Weak';
DECLARE @t datetime2(7) = SYSDATETIME();
DECLARE @i int = 1;
WHILE @i <= 500000
BEGIN
  EXEC dbo.usp_Fake;
  SET @i = @i + 1;
END;
SELECT DATEDIFF(ms, @t, SYSDATETIME()) milisekund;
REVERT;
GO

-- A mo¿e byæ jeszcze gorzej - procedura nazwana od sp_
GO
IF OBJECT_ID('dbo.sp_Fake', 'P') IS NOT NULL
  DROP PROC dbo.sp_Fake;
GO
CREATE PROC dbo.sp_Fake
AS;
GO
GRANT EXECUTE ON OBJECT::dbo.sp_Fake TO Weak;
GO
EXECUTE AS USER = 'Weak';
DECLARE @t datetime2(7) = SYSDATETIME();
DECLARE @i int = 1;
WHILE @i <= 500000
BEGIN
  EXEC sp_Fake;
  SET @i = @i + 1;
END;
SELECT DATEDIFF(ms, @t, SYSDATETIME()) milisekund;
REVERT;
GO

EXECUTE AS USER = 'Weak';
DECLARE @t datetime2(7) = SYSDATETIME();
DECLARE @i int = 1;
WHILE @i <= 500000
BEGIN
  EXEC dbo.sp_Fake;
  SET @i = @i + 1;
END;
SELECT DATEDIFF(ms, @t, SYSDATETIME()) milisekund;
REVERT;
GO




-- Czy to znaczy, ¿e mo¿na ju¿ u¿ywaæ bezpiecznie przedrostka sp_, 
-- jeœli pamiêtamy o dbo?

-- Nie do koñca. Wszystko zale¿y od tego, jak¹ wybierzemy nazwê :)
GO
CREATE PROCEDURE dbo.sp_help
AS
SELECT 'How can I help you?' AS Mess;
GO

-- wywo³ujemy
EXEC sp_help;
GO

-- pewnie wszystko przez brak dbo....
EXEC dbo.sp_help;
GO

-- ??
EXEC sp_helptext 'dbo.sp_help';
GO
DROP PROCEDURE dbo.sp_help;
GO

-- takie usuwanie bez sprawdzenia czy obiekt istnieje? Powinno siê to robiæ tak?
IF OBJECT_ID('dbo.sp_help') IS NOT NULL
  DROP PROCEDURE dbo.sp_help;
GO
-- w tym szczególnym wypadku trzeba tak!
IF EXISTS (SELECT * FROM sys.objects o 
  WHERE o.schema_id = SCHEMA_ID('dbo') AND o.name = 'sp_help' AND o.type = 'P')
  DROP PROCEDURE dbo.sp_help;
GO

-- jeszcze jeden przyk³ad - to nie tylko problem sp_, ale ca³ego schematu sys!
CREATE TABLE dbo.sysobjects (a int);
GO
SELECT TOP 10 * FROM dbo.sysobjects;
GO
EXEC sp_help 'dbo.sysobjects';
GO
DROP TABLE dbo.sysobjects;
GO


-- Best practice: jak siê uchroniæ przed ryzykiem teraz i w przysz³oœci?
IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'DDLTR_CREATE_SYSLIKE_OBJECT')
  DROP TRIGGER DDLTR_CREATE_SYSLIKE_OBJECT ON DATABASE;
GO
CREATE TRIGGER DDLTR_CREATE_SYSLIKE_OBJECT
ON DATABASE
FOR 
CREATE_TABLE, 
CREATE_VIEW, 
CREATE_PROCEDURE, 
CREATE_FUNCTION
AS
BEGIN
  DECLARE @ObjectName sysname, @SchemaName sysname;
  DECLARE @E xml = EVENTDATA();
  SELECT 
    @ObjectName = @E.value('(/EVENT_INSTANCE/ObjectName)[1]','nvarchar(128)'),
    @SchemaName = @E.value('(/EVENT_INSTANCE/SchemaName)[1]','nvarchar(128)');
  IF @SchemaName = N'dbo' 
  AND EXISTS (
              SELECT 1 FROM sys.all_objects o 
              WHERE o.name = @ObjectName 
              AND o.schema_id = SCHEMA_ID('sys')
              )
  BEGIN
    RAISERROR('Object already exists in sys schema. Choose another name.',16,1);
    ROLLBACK;
  END;
END;
GO

-- Test 
CREATE PROCEDURE dbo.sp_helptext
AS;
GO

-- cleanup
USE master;
GO
ALTER DATABASE TestDb SET READ_ONLY WITH ROLLBACK IMMEDIATE;
GO
DROP DATABASE TestDb;
GO