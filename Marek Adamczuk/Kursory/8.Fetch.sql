use CursorDb
GO
IF OBJECT_ID('dbo.FetchPrior','P') IS NOT NULL DROP PROCEDURE dbo.FetchPrior
GO
CREATE PROCEDURE dbo.FetchPrior
AS
DECLARE 
@row_nr int, 
@obj_name sysname, 
@col_name sysname, 
@data_type sysname, 
@obj_type varchar(2),
@is_nullable bit
FETCH PRIOR FROM c INTO @row_nr, @obj_name, @col_name, @data_type, @obj_type, @is_nullable;
SELECT 
	@@FETCH_STATUS FS, 
	@row_nr row_nr, 
	@obj_name obj_name, 
	@col_name col_name, 
	@obj_type obj_type,
	@is_nullable is_null
GO
IF OBJECT_ID('dbo.FetchRelative','P') IS NOT NULL DROP PROCEDURE dbo.FetchRelative
GO
CREATE PROCEDURE dbo.FetchRelative @cnt int
AS
DECLARE 
@row_nr int, 
@obj_name sysname, 
@col_name sysname, 
@data_type sysname, 
@obj_type varchar(2),
@is_nullable bit
FETCH RELATIVE @cnt FROM c INTO @row_nr, @obj_name, @col_name, @data_type, @obj_type, @is_nullable;
SELECT 
	@@FETCH_STATUS FS, 
	@row_nr row_nr, 
	@obj_name obj_name, 
	@col_name col_name, 
	@obj_type obj_type,
	@is_nullable is_null
GO
IF OBJECT_ID('dbo.FetchAbsolute','P') IS NOT NULL DROP PROCEDURE dbo.FetchAbsolute
GO
CREATE PROCEDURE dbo.FetchAbsolute @cnt int
AS
DECLARE 
@row_nr int, 
@obj_name sysname, 
@col_name sysname, 
@data_type sysname, 
@obj_type varchar(2),
@is_nullable bit
FETCH ABSOLUTE @cnt FROM c INTO @row_nr, @obj_name, @col_name, @data_type, @obj_type, @is_nullable;
SELECT 
	@@FETCH_STATUS FS, 
	@row_nr row_nr, 
	@obj_name obj_name, 
	@col_name col_name, 
	@obj_type obj_type,
	@is_nullable is_null
GO
EXEC dbo.CleanupCurAndTab;

declare c cursor scroll for select * From dbo.cursor_tab
open c;
select * from sys.dm_exec_cursors(0)


-- testy

EXEC dbo.FetchNext
GO 50
EXEC dbo.FetchPrior 
GO 30
EXEC dbo.FetchAbsolute 60
GO
EXEC dbo.FetchRelative 10
GO
EXEC dbo.FetchRelative -10
GO
