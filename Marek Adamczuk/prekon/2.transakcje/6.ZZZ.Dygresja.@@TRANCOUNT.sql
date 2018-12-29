-- @@TRANCOUNT -- poziom zagnie¿d¿enia transakcji
SET NOCOUNT ON; -- wy³¹czamy (x row(s) affected)
GO
SELECT @@TRANCOUNT bez_transakcji;
BEGIN TRAN
  SELECT @@TRANCOUNT tran1;
COMMIT TRAN;
GO
SELECT @@TRANCOUNT bez_transakcji;
BEGIN TRAN
  SELECT @@TRANCOUNT tran1;
  BEGIN TRAN
    SELECT @@TRANCOUNT tran2;
  COMMIT TRAN;
  SELECT @@TRANCOUNT po_tran2;
COMMIT TRAN;
SELECT @@TRANCOUNT po_ostatnim_commit;
GO
SELECT @@TRANCOUNT bez_transakcji;
BEGIN TRAN
  SELECT @@TRANCOUNT tran1;
  BEGIN TRAN
    SELECT @@TRANCOUNT tran2;
  ROLLBACK TRAN;
  SELECT @@TRANCOUNT po_tran2;
ROLLBACK TRAN;
GO
-- ********** @@TRANCOUNT WEWN¥TRZ TRIGGERA ************
IF OBJECT_ID('dbo.temp_TranTab') IS NOT NULL DROP TABLE dbo.temp_TranTab 
GO
CREATE TABLE dbo.temp_TranTab (
  i int, 
  dummy varchar(50) NULL,
  CONSTRAINT PK_temp_TranTab PRIMARY KEY(i)
  )
GO
IF OBJECT_ID('dbo.temp_tr_TranTab') IS NOT NULL DROP TRIGGER dbo.temp_tr_TranTab;
GO
CREATE TRIGGER dbo.temp_tr_TranTab
ON dbo.temp_TranTab FOR INSERT
AS
BEGIN
  SELECT @@TRANCOUNT AS TranCntInTrigger;
END;
GO
INSERT INTO dbo.temp_TranTab (i) VALUES (100);
GO
BEGIN TRAN;
  INSERT INTO dbo.temp_TranTab (i) VALUES (200);
COMMIT TRAN;
GO
ALTER TRIGGER dbo.temp_tr_TranTab
ON dbo.temp_TranTab FOR INSERT
AS
BEGIN
  SELECT @@TRANCOUNT AS TranCntInTrigger;
  select * from sys.dm_tran_session_transactions t WHERE t.session_id = @@SPID;
END;
GO
DELETE temp_TranTab; 
INSERT INTO dbo.temp_TranTab (i) VALUES (300);
SELECT @@TRANCOUNT;
GO
BEGIN TRAN;
  INSERT INTO dbo.temp_TranTab (i) VALUES (401);
select * from sys.dm_tran_session_transactions t WHERE t.session_id = @@SPID;
COMMIT TRAN;

-- *********** @@TRANCOUNT W DEFAULT ************
GO
IF OBJECT_ID('dbo.temp_tr_TranTab') IS NOT NULL DROP TRIGGER dbo.temp_tr_TranTab
GO
ALTER TABLE dbo.temp_TranTab ADD TranCnt int DEFAULT @@TRANCOUNT;
GO
INSERT INTO dbo.temp_TranTab (i) SELECT -1001;
GO
SELECT * FROM dbo.temp_TranTab;
GO
BEGIN TRAN;
INSERT INTO dbo.temp_TranTab (i) SELECT -1002;
COMMIT TRAN;
SELECT * FROM dbo.temp_TranTab;
GO
BEGIN TRAN;
BEGIN TRAN;

INSERT INTO dbo.temp_TranTab (i) SELECT -1003;
COMMIT TRAN;
COMMIT TRAN;
SELECT * FROM dbo.temp_TranTab;
GO
-------- TRYB Implicit transactions ------------

SET IMPLICIT_TRANSACTIONS ON
SELECT @@TRANCOUNT TranCnt;
SELECT * FROM dbo.temp_TranTab WITH (NOLOCK);
SELECT @@TRANCOUNT TranCnt;
INSERT INTO dbo.temp_TranTab (i) SELECT -10000;
SELECT @@TRANCOUNT TranCnt;
DROP TABLE dbo.temp_TranTab;
SELECT @@TRANCOUNT TranCnt;
ROLLBACK TRAN;
SELECT @@TRANCOUNT TranCnt;
SELECT * FROM dbo.temp_TranTab;
GO
SET IMPLICIT_TRANSACTIONS OFF
GO
IF @@trancount>0 ROLLBACK;
GO
IF OBJECT_ID('dbo.temp_Ins_TranTab') IS NOT NULL DROP PROCEDURE dbo.temp_Ins_TranTab;
GO
CREATE PROCEDURE dbo.temp_Ins_TranTab
AS
-- commit bez begin tran!
INSERT INTO dbo.temp_TranTab(i) SELECT MAX(i)+1 FROM dbo.temp_TranTab;
COMMIT TRAN;
GO
SET IMPLICIT_TRANSACTIONS ON
GO
SELECT @@TRANCOUNT TranCnt;
EXEC dbo.temp_Ins_TranTab;
SELECT @@TRANCOUNT TranCnt;
GO
-- CHECK NA TRANCOUNT W TRYBIE IMPLICIT_TRANSACTIONS

SET IMPLICIT_TRANSACTIONS OFF
GO
IF OBJECT_ID('dbo.BeginTran') IS NOT NULL DROP PROCEDURE dbo.BeginTran;
GO
CREATE PROCEDURE dbo.BeginTran
AS
BEGIN TRAN;
GO
IF OBJECT_ID('dbo.CommitTran') IS NOT NULL DROP PROCEDURE dbo.CommitTran;
GO
CREATE PROCEDURE dbo.CommitTran
AS
COMMIT TRAN;
GO
IF OBJECT_ID('dbo.RollbackTran') IS NOT NULL DROP PROCEDURE dbo.RollbackTran;
GO
CREATE PROCEDURE dbo.RollbackTran
AS
ROLLBACK TRAN;
GO
SET IMPLICIT_TRANSACTIONS ON
EXEC dbo.BeginTran -- Uwaga na @@TRANCOUNT
SELECT @@TRANCOUNT
EXEC dbo.CommitTran
SELECT @@TRANCOUNT
EXEC dbo.CommitTran
SELECT @@TRANCOUNT
GO
EXEC dbo.BeginTran
SELECT @@TRANCOUNT
EXEC dbo.RollbackTran
SELECT @@TRANCOUNT
GO
SET ANSI_DEFAULTS ON;
GO
