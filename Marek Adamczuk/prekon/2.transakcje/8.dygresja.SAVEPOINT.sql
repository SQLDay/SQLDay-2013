-- transakcje nazwane

IF OBJECT_ID('tempdb.dbo.#t') IS NOT NULL DROP TABLE #t;
CREATE TABLE #t (i int);

-- nie nazywamy transakcji przy begin i commit - to (niemal) bez znaczenia!
BEGIN TRAN jedna;
SELECT @@TRANCOUNT AS inside;
INSERT #t(i) SELECT 5;
COMMIT TRAN druga;
SELECT @@TRANCOUNT AS outside;
GO

-- tylko w tym przypadku przy begin ma :)
BEGIN TRAN jedna;
SELECT @@TRANCOUNT AS inside;
INSERT #t(i) SELECT 5;
ROLLBACK TRAN druga;
SELECT @@TRANCOUNT AS outside;
GO

BEGIN TRAN jedna;
SELECT @@TRANCOUNT AS inside;
INSERT #t(i) SELECT 5;
ROLLBACK TRAN jedna;
SELECT @@TRANCOUNT AS outside;
GO


IF @@TRANCOUNT>0 ROLLBACK TRAN;
TRUNCATE TABLE #t;

BEGIN TRAN;
INSERT INTO #t(i) SELECT 0;
SELECT @@TRANCOUNT AS after_begin_tran;

SAVE TRAN a;
INSERT INTO #t(i) SELECT 1;
SELECT @@TRANCOUNT AS after_save_a;

SAVE TRAN b;
INSERT INTO #t(i) SELECT 2;
SELECT @@TRANCOUNT AS after_save_b;

ROLLBACK TRAN a;
SELECT * FROM #t;
SELECT @@TRANCOUNT AS after_rollback_a;
ROLLBACK;
SELECT * FROM #t;
GO


-- co siê dzieje przy duplikacji savepointów
IF @@TRANCOUNT>0 ROLLBACK TRAN;
TRUNCATE TABLE #t;

BEGIN TRAN;
INSERT INTO #t(i) SELECT 0;
SELECT @@TRANCOUNT AS after_begin_tran;
GO
SAVE TRAN a;
INSERT INTO #t(i) SELECT 1;
SELECT @@TRANCOUNT AS after_save_a;
GO
SAVE TRAN b;
INSERT INTO #t(i) SELECT 2;
SELECT @@TRANCOUNT AS after_first_b;
GO
SAVE TRAN c;
INSERT INTO #t(i) SELECT 3;
SELECT @@TRANCOUNT after_save_c;
GO
SAVE TRAN b; -- UWAGA! ZNOWU b
INSERT INTO #t(i) SELECT 4;
SELECT @@TRANCOUNT after_second_b;
GO
SAVE TRAN b;
INSERT INTO #t(i) SELECT 5;
SELECT @@TRANCOUNT after_third_b;
GO

SELECT * FROM #t; -- dla ustalenia uwagi :)
ROLLBACK TRAN b; -- które b siê zrollbackuje?
SELECT * FROM #t;
SELECT @@TRANCOUNT;
ROLLBACK TRAN;
GO
-- a co gdy savepoint zagnieŸdzimy w procedurze?
IF @@TRANCOUNT>0 ROLLBACK TRAN;
TRUNCATE TABLE #t;
GO
IF OBJECT_ID ('dbo.Save_B') IS NOT NULL DROP PROCEDURE dbo.Save_B; 
GO
CREATE PROCEDURE dbo.Save_B @i int
AS
SAVE TRAN b;
INSERT INTO #t(i) VALUES (@i); 
GO
BEGIN TRAN;
INSERT INTO #t(i) SELECT 0;

SAVE TRAN a;
INSERT INTO #t(i) SELECT 1;

SAVE TRAN b;
INSERT INTO #t(i) SELECT 2;

EXEC dbo.Save_B 3; -- teraz nie widzimy, ¿e wewn¹trz procedury jest SAVE TRAN b

ROLLBACK TRAN b; -- które b siê zrollbackuje?

SELECT * FROM #t; 




-- to wewn¹trz procedury, a my nawet o tym nie wiemy!!!
SELECT @@TRANCOUNT;
ROLLBACK;
GO
-- WNIOSEK! Savepointy powinny nazywaæ siê unikalnie!!
-- Inaczej ryzykujemy ROLLBACK do nieznanego miejsca!!!
-- JAK JE GENEROWAÆ?


BEGIN TRAN;
DECLARE @SavePointA varchar(100); 
SET @SavePointA = 'T123456789012345678901234567890123456789012345678901234567890123456789A';
DECLARE @SavePointB varchar(100); 
SET @SavePointB = 'T123456789012345678901234567890123456789012345678901234567890123456789B';
INSERT INTO #t(i) SELECT 0;
SAVE TRAN @SavePointA;
INSERT INTO #t(i) SELECT 1;
SAVE TRAN @SavePointB;
INSERT INTO #t(i) SELECT 2;
ROLLBACK TRAN @SavePointA; -- spodziewamy siê tylko jednego rekordu z i = 0
GO
SELECT * FROM #t; 
ROLLBACK;


-- naprawiamy
BEGIN TRAN;
DECLARE @SavePointA varchar(100); 
SET @SavePointA = 'T123456789012345678901234567890123456789012345678901234567890123456789A';
DECLARE @SavePointB varchar(100); 
SET @SavePointB = '_123456789012345678901234567890123456789012345678901234567890123456789B';
INSERT INTO #t(i) SELECT 0;
SAVE TRAN @SavePointA;
INSERT INTO #t(i) SELECT 1;
SAVE TRAN @SavePointB;
INSERT INTO #t(i) SELECT 2;
ROLLBACK TRAN @SavePointA; -- spodziewamy siê tylko jednego rekordu z i = 0
GO
SELECT * FROM #t; 
ROLLBACK;

-- Wa¿ne tylko pierwsze 32 znaki. Literalnie tylko tyle da siê zapisaæ
ROLLBACK;

-- Nazwa procedury? NIE: Mo¿e byæ zbyt d³uga + wywo³anie rekursywne!
GO
IF OBJECT_ID ('dbo.Safe_Save_Tran') IS NOT NULL DROP PROCEDURE dbo.Safe_Save_Tran;
GO
CREATE PROCEDURE dbo.Safe_Save_Tran @i int
AS
DECLARE @SavePoint varchar(40) SET @SavePoint = REPLACE(CONVERT(VARCHAR(36),NEWID()),'-','');
-- SELECT @SavePoint;
SAVE TRAN @SavePoint;
INSERT INTO #t(i) VALUES (@i); 
-- IF SOMETHING_GOES_WRONG ROLLBACK TRAN @SavePoint;
GO
IF @@TRANCOUNT>0 ROLLBACK TRAN;
TRUNCATE TABLE #t
BEGIN TRAN;
INSERT INTO #t(i) SELECT 0;
SAVE TRAN a;
INSERT INTO #t(i) SELECT 1;
SAVE TRAN b;
INSERT INTO #t(i) SELECT 2;
EXEC dbo.Safe_Save_Tran 3
ROLLBACK TRAN b;
SELECT * FROM #t;
GO
