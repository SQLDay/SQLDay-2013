use CursorDb
GO
UPDATE dbo.cursor_tab SET data_type = data_type+'?' WHERE row_nr = 1;
GO
SELECT * FROM dbo.cursor_tab 
WHERE 
--CURRENT OF c;
row_nr = 1;
