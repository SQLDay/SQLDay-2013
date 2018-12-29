USE CursorDb

declare @c int
exec sp_cursoropen @c out, N'select * from cursor_tab'
select @c
GO
SELECT * FROM sys.dm_exec_cursors(0)
GO
-- tak �ci�gamy nast�pne 10 wierszy
exec sp_cursorfetch 
  180150003, -- handle kursora
  2, -- next row
  0, -- ? niby row_number ale si� nie zwraca  :(
  10 -- liczba rekord�w
GO
--
exec sp_cursor 
  180150003, -- handle kursora
  33, -- update
  2,  -- drugi wiersz z bufora
  '', -- tabela, przy jednej mo�na odpu�ci�
  @data_type = 'NOWY_LEPSZY', @obj_type = '?'
GO
select * From dbo.cursor_tab where row_nr between 50 and 60
GO
exec sp_cursor
  180150003, -- handle kursora
  34, -- delete
  6,  -- sz�sty wiersz z bufora
  ''
GO
select * From dbo.cursor_tab where row_nr between 50 and 60

exec sp_cursorclose 180150003;

