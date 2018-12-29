--------SET NOCOUNT ON -------------------
GO
IF OBJECT_ID('dbo.TestNOCOUNT') IS NOT NULL DROP PROCEDURE dbo.TestNOCOUNT;
GO
CREATE PROCEDURE dbo.TestNOCOUNT @Iterations int = 200000
AS
SET NOCOUNT OFF;
BEGIN
  DECLARE @i int = 0;
  CREATE TABLE #t (a int);
  WHILE @i < @Iterations BEGIN
    INSERT INTO #t (a) SELECT 1;
    DELETE FROM #t;
    SET @i = @i + 1;
  END;
END;
GO
-- Ctrl+T; Task Manager + Czas 
DECLARE @date datetime = GETDATE();
EXEC dbo.TestNOCOUNT;
SELECT DATEDIFF (ms,@date,GETDATE()) ms;
GO
ALTER PROCEDURE dbo.TestNOCOUNT @Iterations int = 200000
AS
SET NOCOUNT ON;
BEGIN
  DECLARE @i int = 0;
  CREATE TABLE #t (a int);
  WHILE @i < @Iterations BEGIN
    INSERT INTO #t (a) SELECT 1;
    DELETE FROM #t;
    SET @i = @i + 1;
  END;
END;
GO
DECLARE @date datetime = GETDATE();
EXEC dbo.TestNOCOUNT;
SELECT DATEDIFF (ms,@date,GETDATE()) ms;
GO
