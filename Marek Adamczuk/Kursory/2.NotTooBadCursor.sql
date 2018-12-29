USE AdventureWorks2012;
GO
CREATE TABLE dbo.TaxPayments (
  PaymentId int,
  MaxAmount money,
  AllocatedAmount money,
  CONSTRAINT PK_TaxPayments PRIMARY KEY (PaymentId)
  )
GO  
CREATE TABLE dbo.PaymentOrders (
  PaymentId int,
  SalesOrderID int
  )
GO
SET NOCOUNT ON;
DELETE FROM dbo.TaxPayments;
DELETE FROM dbo.PaymentOrders;
GO
INSERT dbo.TaxPayments (PaymentId, MaxAmount, AllocatedAmount) VALUES (1,10000,0)
INSERT dbo.TaxPayments (PaymentId, MaxAmount, AllocatedAmount) VALUES (2,8000,0)
INSERT dbo.TaxPayments (PaymentId, MaxAmount, AllocatedAmount) VALUES (3,12000,0)
INSERT dbo.TaxPayments (PaymentId, MaxAmount, AllocatedAmount) VALUES (4,7000,0)
INSERT dbo.TaxPayments (PaymentId, MaxAmount, AllocatedAmount) VALUES (5,30000,0)
INSERT dbo.TaxPayments (PaymentId, MaxAmount, AllocatedAmount) VALUES (6,30000,0)
INSERT dbo.TaxPayments (PaymentId, MaxAmount, AllocatedAmount) VALUES (7,9000,0)
GO
IF OBJECT_ID('dbo.AssignOrdersToPayment','P') IS NOT NULL 
  DROP PROCEDURE dbo.AssignOrdersToPayment
GO
CREATE PROCEDURE dbo.AssignOrdersToPayment
AS
BEGIN
	-- przyporz¹dkuj do najbli¿szej p³atnoœci, chyba, ¿e siê nie mieœci w maksymalnej kwocie
	-- na p³atnoœci zapisz kwotê do zap³aty. 1 zamówienie w jednej zap³acie
  SET XACT_ABORT ON
	DECLARE @SalesOrderId int, @TaxAmount money, @PaymentId int;
	DECLARE c CURSOR LOCAL FAST_FORWARD FOR
	SELECT h.SalesOrderId, h.TaxAmt FROM Sales.SalesOrderHeader h ORDER BY h.SalesOrderId;
	OPEN c;
	FETCH NEXT FROM c INTO @SalesOrderId, @TaxAmount;
	WHILE @@FETCH_STATUS = 0 BEGIN
	  SELECT TOP 1 @PaymentId = p.PaymentId 
		FROM dbo.TaxPayments p WHERE p.AllocatedAmount+@TaxAmount <= p.MaxAmount
	  IF @@ROWCOUNT=0 BREAK;
	  BEGIN TRAN;
	    UPDATE dbo.TaxPayments SET AllocatedAmount = AllocatedAmount + @TaxAmount 
	    WHERE PaymentId = @PaymentId;
	    INSERT INTO dbo.PaymentOrders (PaymentId, SalesOrderId) VALUES (@PaymentId, @SalesOrderId);
	  COMMIT TRAN;
	  FETCH NEXT FROM c INTO @SalesOrderId, @TaxAmount;
	END;
	CLOSE c; DEALLOCATE c;
END;
GO
-- test 
EXEC dbo.AssignOrdersToPayment;
SELECT * FROM dbo.TaxPayments;
GO
-- Sprawdzenie
SELECT p.MaxAmount, po.*, soh.TaxAmt,
sum(soh.TaxAmt) over (partition by po.PaymentId order by soh.SalesOrderId rows unbounded preceding) RunningTotal
FROM dbo.PaymentOrders po JOIN Sales.SalesOrderHeader soh on po.SalesOrderID = soh.SalesOrderID
JOIN dbo.TaxPayments p on p.PaymentId = po.PaymentId
order by soh.SalesOrderID;
GO
-- Cleanup
DROP TABLE dbo.TaxPayments;
DROP TABLE dbo.PaymentOrders;
GO
-- do domu: ZnaleŸæ rozwi¹zanie oparte na zbiorach
-- Sprawdziæ wydajnoœæ
-- Oceniæ poziom skomplikowania zapytania
-- Zastanowiæ siê, ile wymaga³oby przeróbek, gdybyœmy zmienili kolejnoœæ zamówieñ do p³atnoœci