IF DB_ID('CursorDb') IS NULL CREATE DATABASE CursorDb
GO
USE CursorDb
GO
IF OBJECT_ID('dbo.MakeCursorTab') IS NOT NULL DROP PROC dbo.MakeCursorTab;
GO
CREATE PROCEDURE dbo.MakeCursorTab
AS
-- tworzy od now¹ tabelê do æwiczeñ z kursorami
IF OBJECT_ID('dbo.cursor_tab') IS NOT NULL DROP TABLE dbo.cursor_tab;
SELECT 
 ROW_NUMBER() OVER (ORDER BY OBJECT_NAME(c.object_id),c.column_id) row_nr,
 OBJECT_NAME(c.object_id) obj_name,
 c.name AS col_name,
 TYPE_NAME(c.system_type_id) data_type,
 convert(varchar(2),o.type) obj_type,
 c.is_nullable
 into dbo.cursor_tab
 FROM sys.all_columns c 
 JOIN sys.all_objects o ON c.object_id = o.object_id
 WHERE o.schema_id = SCHEMA_ID('sys')
 ORDER BY row_nr;
GO
EXEC dbo.MakeCursorTab;
GO
select * from dbo.cursor_tab ORDER BY row_nr;
GO
IF OBJECT_ID('dbo.FetchNext') IS NOT NULL DROP PROCEDURE dbo.FetchNext;
GO
CREATE PROCEDURE dbo.FetchNext
AS
-- wydobywa kolejny rekord z kursora globalnego i wyœwietla œci¹gniête dane
DECLARE 
@row_nr int, 
@obj_name sysname, 
@col_name sysname, 
@data_type sysname, 
@obj_type varchar(2),
@is_nullable bit
FETCH NEXT FROM c INTO @row_nr, @obj_name, @col_name, @data_type, @obj_type, @is_nullable;
SELECT 
	@@FETCH_STATUS FS, 
	@row_nr row_nr, 
	@obj_name obj_name, 
	@col_name col_name, 
	@obj_type obj_type,
	@is_nullable is_null
GO
IF OBJECT_ID('dbo.CleanupCurAndTab') IS NOT NULL DROP PROCEDURE dbo.CleanupCurAndTab;
GO
CREATE PROCEDURE dbo.CleanupCurAndTab
AS
EXEC dbo.MakeCursorTab;
IF EXISTS (SELECT 1 FROM sys.dm_exec_cursors(@@SPID) WHERE name = 'c')
  DEALLOCATE c;
GO
EXEC dbo.CleanupCurAndTab;
GO
-- kursor domyœlny: Dynamic
DECLARE c CURSOR FOR SELECT * FROM dbo.cursor_tab;
SELECT * FROM sys.dm_exec_cursors(0)--sprawdzamy
OPEN c;
GO
-- tekst zapytania?
SELECT t.text, c.*
FROM sys.dm_exec_cursors (0) c
OUTER APPLY sys.dm_exec_sql_text(c.sql_handle) t
GO
-- rzut oka na stan posiadania
SELECT * FROM dbo.cursor_tab t WHERE t.obj_name = 'all_columns'
GO
EXEC dbo.FetchNext;
GO 4
DELETE FROM dbo.cursor_tab WHERE row_nr = 6;
UPDATE dbo.cursor_tab SET [col_name] = [col_name]+'!!!!' where row_nr = 10;
GO
EXEC dbo.FetchNext;
GO 6

DELETE FROM dbo.cursor_tab WHERE row_nr = 14
INSERT INTO dbo.cursor_tab(row_nr, obj_type) SELECT 14,'?';
GO
EXEC dbo.FetchNext;
GO 4



-- kursor jawnie dynamiczny!
EXEC dbo.CleanupCurAndTab;
GO
ALTER TABLE dbo.cursor_tab ADD UNIQUE CLUSTERED (row_nr);
DECLARE c CURSOR FOR SELECT * FROM dbo.cursor_tab ORDER BY row_nr;
SELECT * FROM sys.dm_exec_cursors(0)--sprawdzamy
OPEN c;
GO
GO
EXEC dbo.FetchNext;
GO 4
DELETE FROM dbo.cursor_tab WHERE row_nr = 6;
UPDATE dbo.cursor_tab SET [col_name] = [col_name]+'!!!!' where row_nr = 10;
GO
EXEC dbo.FetchNext;
GO 6

DELETE FROM dbo.cursor_tab WHERE row_nr = 14
INSERT INTO dbo.cursor_tab(row_nr, obj_type) SELECT 14,'?';
GO
EXEC dbo.FetchNext;
GO 4



DELETE FROM dbo.cursor_tab 
GO
EXEC dbo.FetchNext;
GO
INSERT INTO dbo.cursor_tab(row_nr, obj_type) SELECT 20,'?';
GO
EXEC dbo.FetchNext;
GO

-- kursor statyczny
EXEC dbo.CleanupCurAndTab;

DECLARE c CURSOR STATIC FOR 
SELECT * FROM dbo.cursor_tab
ORDER BY row_nr
OPEN c;
SELECT * FROM sys.dm_exec_cursors(0)
GO

SELECT * FROM dbo.cursor_tab t WHERE t.obj_name = 'all_columns'
GO
EXEC dbo.FetchNext;
GO 4
DELETE FROM dbo.cursor_tab WHERE row_nr = 6;
UPDATE dbo.cursor_tab SET [col_name] = [col_name]+'!!!!' where row_nr = 10;
GO
EXEC dbo.FetchNext;
GO 6

DELETE FROM dbo.cursor_tab; 
EXEC dbo.FetchNext;
GO 10

DROP TABLE dbo.cursor_tab;
GO
EXEC dbo.FetchNext;
GO 3

-- kursor keyset
GO
EXEC dbo.CleanupCurAndTab;
GO
alter table cursor_tab alter column row_nr int NOT NULL
GO
alter table cursor_tab add primary key (row_nr)
GO
DECLARE c CURSOR KEYSET FOR 
SELECT * FROM dbo.cursor_tab
ORDER BY row_nr
OPEN c;
SELECT * FROM sys.dm_exec_cursors(0)
GO
GO
EXEC dbo.FetchNext;
GO 4
DELETE FROM dbo.cursor_tab WHERE row_nr = 6;
UPDATE dbo.cursor_tab SET [col_name] = [col_name]+'!!!!!' where row_nr = 10;
GO
EXEC dbo.FetchNext;
GO 6
DELETE FROM dbo.cursor_tab; 
EXEC dbo.FetchNext;
GO
DROP TABLE dbo.cursor_tab;
EXEC dbo.FetchNext;
GO


-- Jeszce próba z wieloma kluczami, co wa¿niejsze? Primary key, czy klucz klastrowany?
EXEC dbo.CleanupCurAndTab;
GO
alter table cursor_tab alter column row_nr int NOT NULL
GO
alter table cursor_tab add primary key nonclustered (row_nr)
GO
alter table cursor_tab add unique clustered  (obj_name,[col_name])
GO
-- 
DECLARE c CURSOR KEYSET FOR 
SELECT * FROM dbo.cursor_tab
ORDER BY row_nr
OPEN c;
SELECT * FROM sys.dm_exec_cursors(0)
GO
GO
EXEC dbo.FetchNext;
GO 4
DELETE FROM dbo.cursor_tab WHERE row_nr = 6;
-- teraz naruszamy kawa³ek klucza klastrowanego, ale nie primary key!
UPDATE dbo.cursor_tab SET [col_name] = [col_name]+'!!!!!' where row_nr = 10; 
GO
EXEC dbo.FetchNext;
GO 6
DELETE FROM dbo.cursor_tab; 
EXEC dbo.FetchNext;
GO
DROP TABLE dbo.cursor_tab;
EXEC dbo.FetchNext;
GO



-- i jeszcze indeks "nieunikalny" klastrowany
EXEC dbo.CleanupCurAndTab;
GO
update cursor_tab set is_nullable = 0
create clustered index clst on cursor_tab (is_nullable)
GO
DECLARE c CURSOR KEYSET FOR 
SELECT * FROM dbo.cursor_tab
ORDER BY row_nr
OPEN c;
SELECT * FROM sys.dm_exec_cursors(0)
GO
EXEC dbo.FetchNext;
GO 4
DELETE FROM dbo.cursor_tab WHERE row_nr = 6;
-- teraz naruszamy kawa³ek klucza klastrowanego, ale nie primary key!
UPDATE dbo.cursor_tab SET [col_name] = [col_name]+'!!!!!' where row_nr = 10; 
GO
EXEC dbo.FetchNext;
GO 6


UPDATE dbo.cursor_tab SET row_nr = 0, obj_name = '!QAZ', col_name = 'XZXZX', obj_type = '?'
EXEC dbo.FetchNext;
GO
UPDATE dbo.cursor_tab SET is_nullable = 1
GO
EXEC dbo.FetchNext;
GO 10




-- i naprawdê nieunikalny
EXEC dbo.CleanupCurAndTab;
GO
update cursor_tab set is_nullable = 0
create nonclustered index clst on cursor_tab (is_nullable)
GO
DECLARE c CURSOR KEYSET FOR 
SELECT * FROM dbo.cursor_tab
ORDER BY row_nr
OPEN c;
SELECT * FROM sys.dm_exec_cursors(0)
GO
