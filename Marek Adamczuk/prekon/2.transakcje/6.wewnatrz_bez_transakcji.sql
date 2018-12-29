USE Magazyn;
GO
IF OBJECT_ID('dbo.WstawDowodMag_NO_TRAN') IS NOT NULL DROP PROC dbo.WstawDowodMag_NO_TRAN;
GO
CREATE PROCEDURE dbo.WstawDowodMag_NO_TRAN 
  @Rodzaj varchar(2), 
  @Pozycje TPozycjeDow READONLY,
  @DowId int OUTPUT
AS 
BEGIN
  -- kopia procedury WstawDowodMag bez obs³ugi transakcji
  --BEGIN TRAN;
  INSERT INTO dbo.NaglowkiDow (Rodzaj) VALUES (@Rodzaj);
  IF @@ERROR<>0 GOTO END_ROLLBACK;
    
  SELECT @DowId = SCOPE_IDENTITY();
  IF @@ERROR<>0 GOTO END_ROLLBACK;
  
  INSERT INTO dbo.PozycjeDow (DowId, TowarId, Ilosc)
  SELECT @DowId, p.TowarId, p.Ilosc
  FROM @Pozycje p;
  IF @@ERROR<>0 GOTO END_ROLLBACK;
  
  UPDATE t SET
    t.Stan = t.Stan + CASE @Rodzaj WHEN 'P' THEN 1 WHEN 'R' THEN -1 ELSE 0 END * p.Ilosc
  FROM dbo.Towary t
  JOIN @Pozycje p ON p.TowarId = t.TowarId
  IF @@ERROR<>0 GOTO END_ROLLBACK;
  
  UPDATE n SET 
    n.IloscRazem = (SELECT SUM(p.Ilosc) FROM @Pozycje p),
    n.NumerDow =   ISNULL((SELECT MAX(NumerDow)+1 FROM dbo.NaglowkiDow n),1)
  FROM dbo.NaglowkiDow n
  WHERE n.DowId = @DowId;
  IF @@ERROR<>0 GOTO END_ROLLBACK;
  
  --COMMIT TRAN;
  RETURN 0;
  
  END_ROLLBACK:
  --ROLLBACK TRAN; 
  RETURN -1; 
END;
GO
IF OBJECT_ID('dbo.WstawZamowienie') IS NOT NULL DROP PROCEDURE dbo.WstawZamowienie;
GO
CREATE PROCEDURE dbo.WstawZamowienie @ZamId int, @Pozycje TPozycjeDow READONLY
AS
BEGIN
  DECLARE @DowId int;
  
  BEGIN TRAN;
  
  EXEC dbo.WstawDowodMag_NO_TRAN @Rodzaj = 'R', @Pozycje = @Pozycje, @DowId = @DowId OUTPUT;
  IF @@ERROR <> 0 GOTO END_ROLLBACK;
  
  INSERT INTO dbo.Zamowienia (ZamId, DowId) VALUES (@ZamId, @DowId);
  IF @@ERROR <> 0 GOTO END_ROLLBACK;
  
  COMMIT TRAN;
  RETURN 0;
  
  END_ROLLBACK:
  ROLLBACK TRAN;
  RETURN -1;  
END;
GO
SELECT * FROM dbo.Towary; -- podgl¹damy stany. Ma nie starczyæ T1!
DECLARE @Pozycje TPozycjeDow;
INSERT INTO @Pozycje (TowarId, Ilosc) VALUES ('T1',2),('T3',2);
EXEC dbo.WstawZamowienie @ZamId = 33, @Pozycje = @Pozycje;
GO
-- Ÿle!
SELECT * FROM dbo.Zamowienia WHERE ZamId = 33;
SELECT * FROM dbo.NaglowkiDow 
   WHERE DowId = (SELECT DowId FROM dbo.Zamowienia WHERE ZamId = 33);
   
SELECT * FROM dbo.PozycjeDow 
  WHERE DowId = (SELECT DowId FROM dbo.Zamowienia WHERE ZamId = 33);
SELECT * FROM dbo.Towary;
GO


-- teraz bêdzie lepiej :)
IF OBJECT_ID('dbo.WstawZamowienie') IS NOT NULL DROP PROCEDURE dbo.WstawZamowienie;
GO
CREATE PROCEDURE dbo.WstawZamowienie @ZamId int, @Pozycje TPozycjeDow READONLY
AS
BEGIN
  DECLARE @DowId int, @Return int = 0;
  
  BEGIN TRAN;
  
  -- Z³apaæ wartoœæ zwracan¹!
  EXEC @Return = dbo.WstawDowodMag_NO_TRAN @Rodzaj = 'R', @Pozycje = @Pozycje, @DowId = @DowId OUTPUT;
  IF @Return < 0 GOTO END_ROLLBACK;
  
  INSERT INTO dbo.Zamowienia (ZamId, DowId) VALUES (@ZamId, @DowId);
  IF @@ERROR <> 0 GOTO END_ROLLBACK;
  
  COMMIT TRAN;
  RETURN 0;
  
  END_ROLLBACK:
  ROLLBACK TRAN;
  RETURN -1;  
END;
GO
DECLARE @Pozycje TPozycjeDow;
INSERT INTO @Pozycje (TowarId, Ilosc) VALUES ('T1',2),('T3',2);
EXEC dbo.WstawZamowienie @ZamId = 44, @Pozycje = @Pozycje;
GO
SELECT * FROM dbo.Zamowienia WHERE ZamId = 44;

SELECT * FROM dbo.NaglowkiDow 
   WHERE DowId = (SELECT DowId FROM dbo.Zamowienia WHERE ZamId = 44);
   
SELECT * FROM dbo.PozycjeDow 
  WHERE DowId = (SELECT DowId FROM dbo.Zamowienia WHERE ZamId = 44);
SELECT * FROM dbo.Towary;
GO