use master;
GO
IF DB_ID('CursorDb') IS NOT NULL BEGIN
  ALTER DATABASE CursorDb SET READ_ONLY WITH ROLLBACK IMMEDIATE;
  DROP DATABASE CursorDb;
END;
GO
IF DB_ID('CursorDb') IS NULL
  CREATE DATABASE CursorDb;
GO
SELECT DATABASEPROPERTYEX('model','IsLocalCursorsDefault') CzyDomyslnieLokalny
GO
USE CursorDb
GO
ALTER DATABASE CursorDb SET CURSOR_DEFAULT LOCAL;
GO
SELECT DATABASEPROPERTYEX(db_name(),'IsLocalCursorsDefault')
GO
ALTER DATABASE CursorDb SET CURSOR_DEFAULT GLOBAL;
GO
IF OBJECT_ID('dbo.AddCursor') IS NOT NULL DROP PROCEDURE dbo.AddCursor;
GO
CREATE PROCEDURE dbo.AddCursor
AS
DECLARE c CURSOR FOR SELECT * FROM sys.types;
GO
EXEC dbo.AddCursor;
GO
EXEC dbo.AddCursor;
GO

IF OBJECT_ID('dbo.DeallocateCursor') IS NOT NULL DROP PROCEDURE dbo.DeallocateCursor;
GO
CREATE PROCEDURE dbo.DeallocateCursor
AS
DEALLOCATE c;
GO
EXEC dbo.DeallocateCursor;
GO
EXEC dbo.DeallocateCursor; -- b³¹d
GO
ALTER PROCEDURE dbo.AddCursor
AS
IF NOT EXISTS (SELECT * FROM sys.dm_exec_cursors(@@SPID) WHERE name = 'c')
  DECLARE c CURSOR FOR SELECT * FROM sys.types;
GO
ALTER PROCEDURE dbo.DeallocateCursor
AS
IF EXISTS (SELECT * FROM sys.dm_exec_cursors(@@SPID) WHERE name = 'c')
  DEALLOCATE c;
GO
EXEC dbo.AddCursor;
EXEC dbo.AddCursor;
EXEC dbo.DeallocateCursor;
EXEC dbo.DeallocateCursor;
GO
EXEC dbo.AddCursor;
SELECT * FROM sys.dm_exec_cursors(0) 
GO