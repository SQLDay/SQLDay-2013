USE AdventureWorks2012;
GO
-- zadanie: dla podanego SalesPersonId policzyæ liczbê zamówieñ i ich ca³kowit¹ wartoœæ


IF OBJECT_ID('dbo.CountTotalDueForSalesPersonId_DefaultCursor','P') IS NOT NULL
  DROP PROC dbo.CountTotalDueForSalesPersonId_DefaultCursor
GO
CREATE PROCEDURE dbo.CountTotalDueForSalesPersonId_DefaultCursor @MyId int
AS
BEGIN
  DECLARE @GrantTotalDue money, @Cnt int, @TotalDue money, @SalesPersonId int;
  DECLARE c CURSOR FOR
    SELECT h.SalesPersonId, h.TotalDue FROM Sales.SalesOrderHeader h;
  OPEN c;
  SELECT @GrantTotalDue = 0, @Cnt = 0;
  FETCH NEXT FROM c INTO @SalesPersonId, @TotalDue;  
  WHILE @@FETCH_STATUS = 0 BEGIN
    IF @SalesPersonId = @MyId 
      SELECT @GrantTotalDue = @GrantTotalDue + @TotalDue, @Cnt = @Cnt + 1;
    FETCH NEXT FROM c INTO @SalesPersonId, @TotalDue;  
  END;
  CLOSE c; 
  DEALLOCATE c;
  SELECT @GrantTotalDue MyGrantTotalDue, @Cnt MyCnt;
END;
GO
EXEC dbo.CountTotalDueForSalesPersonId_DefaultCursor 279;
GO
IF OBJECT_ID('dbo.CountTotalDueForSalesPersonId_FasterCursor','P') IS NOT NULL
  DROP PROC dbo.CountTotalDueForSalesPersonId_FasterCursor
GO
CREATE PROCEDURE dbo.CountTotalDueForSalesPersonId_FasterCursor @MyId int
AS
BEGIN
  DECLARE @GrantTotalDue money, @Cnt int, @TotalDue money, @SalesPersonId int;
  DECLARE c CURSOR FAST_FORWARD
  FOR
    SELECT h.SalesPersonId, h.TotalDue FROM Sales.SalesOrderHeader h;
  OPEN c;
  SELECT @GrantTotalDue = 0, @Cnt = 0;
  FETCH NEXT FROM c INTO @SalesPersonId, @TotalDue;  
  WHILE @@FETCH_STATUS = 0 BEGIN
    IF @SalesPersonId = @MyId 
      SELECT @GrantTotalDue = @GrantTotalDue + @TotalDue, @Cnt = @Cnt + 1;
    FETCH NEXT FROM c INTO @SalesPersonId, @TotalDue;  
  END;
  CLOSE c; 
  DEALLOCATE c;
  SELECT @GrantTotalDue MyGrantTotalDue, @Cnt MyCnt;
END;
GO
EXEC dbo.CountTotalDueForSalesPersonId_FasterCursor 279;
GO
IF OBJECT_ID('dbo.CountTotalDueForSalesPersonId_LoopWithoutCursor','P') IS NOT NULL
  DROP PROC dbo.CountTotalDueForSalesPersonId_LoopWithoutCursor
GO
CREATE PROCEDURE dbo.CountTotalDueForSalesPersonId_LoopWithoutCursor @MyId int
AS
BEGIN
  DECLARE @GrantTotalDue money, @Cnt int, @CurrentOrderId int, 
  @TotalDue money, @SalesPersonId int;
  SELECT @GrantTotalDue = 0, @Cnt = 0, @CurrentOrderId = 0;
  
  -- pierwsze zamówienie
  SELECT TOP 1 
    @CurrentOrderId = h.SalesOrderID, 
    @SalesPersonId = h.SalesPersonId,
    @TotalDue = h.TotalDue
    FROM Sales.SalesOrderHeader h 
    WHERE h.SalesOrderID > @CurrentOrderId
    ORDER BY h.SalesOrderID;
  WHILE @@ROWCOUNT > 0 BEGIN
      IF @SalesPersonId = @MyId
        SELECT @Cnt = @Cnt+1, @GrantTotalDue = @GrantTotalDue + @TotalDue;
        
	  SELECT TOP 1 
	    @CurrentOrderId = h.SalesOrderID, 
	    @SalesPersonId = h.SalesPersonId, 
	    @TotalDue = h.TotalDue
		FROM Sales.SalesOrderHeader h 
		WHERE h.SalesOrderID > @CurrentOrderId
		ORDER BY h.SalesOrderID;       
  END;
  SELECT @GrantTotalDue MyGrantTotalDue, @Cnt MyCnt;
END;
GO
EXEC dbo.CountTotalDueForSalesPersonId_LoopWithoutCursor 279;
GO
IF OBJECT_ID('dbo.CountTotalDueForSalesPersonId_SetBased','P') IS NOT NULL
  DROP PROC dbo.CountTotalDueForSalesPersonId_SetBased
GO
CREATE PROCEDURE dbo.CountTotalDueForSalesPersonId_SetBased @MyId int
AS
BEGIN
  SELECT SUM(h.TotalDue) MyGrantTotalDue, COUNT(*) MyCnt
   FROM Sales.SalesOrderHeader h WHERE h.SalesPersonId = @MyId;
END;
GO
EXEC dbo.CountTotalDueForSalesPersonId_SetBased 279;
GO

-- Wszystko razem
GO
EXEC dbo.CountTotalDueForSalesPersonId_DefaultCursor 279;
GO
EXEC dbo.CountTotalDueForSalesPersonId_FasterCursor 279;
GO
EXEC dbo.CountTotalDueForSalesPersonId_LoopWithoutCursor 279;
GO
EXEC dbo.CountTotalDueForSalesPersonId_SetBased 279;
GO




