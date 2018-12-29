USE CursorDb
GO
EXEC dbo.CleanupCurAndTab;
GO
alter table cursor_tab alter column row_nr int NOT NULL
GO
alter table cursor_tab add primary key (row_nr)
GO
DECLARE c CURSOR 
OPTIMISTIC
FOR 
SELECT * FROM dbo.cursor_tab 
ORDER BY row_nr
FOR UPDATE 
SELECT * FROM sys.dm_exec_cursors(0)
OPEN c;
GO


EXEC dbo.FetchNext;
GO
UPDATE dbo.cursor_tab SET data_type = data_type+'!' WHERE CURRENT OF c;
GO
SELECT * FROM dbo.cursor_tab 
WHERE 
--CURRENT OF c;
row_nr = 1;
GO
set language polski

-- scroll locks
EXEC dbo.CleanupCurAndTab;
GO
alter table cursor_tab alter column row_nr int NOT NULL
GO
alter table cursor_tab add primary key (row_nr)
GO


DECLARE c CURSOR SCROLL_LOCKS FOR 
SELECT * FROM dbo.cursor_tab
FOR UPDATE
SELECT * FROM sys.dm_exec_cursors(0)
OPEN c;
GO
EXEC dbo.FetchNext;
GO
sp_lock
GO
UPDATE dbo.cursor_tab SET data_type = data_type+'!' WHERE CURRENT OF c;

SELECT * FROM dbo.cursor_tab 
WHERE 
--CURRENT OF c;
row_nr = 1;
GO
EXEC dbo.FetchNext;