-- odtworzyæ bazê!
USE Magazyn;
GO
SET NOCOUNT ON;
GO
IF OBJECT_ID('dbo.WstawDowodMag') IS NOT NULL DROP PROCEDURE dbo.WstawDowodMag;
GO
CREATE PROCEDURE dbo.WstawDowodMag 
  @Rodzaj varchar(2), 
  @Pozycje TPozycjeDow READONLY,
  @DowId int OUTPUT
AS 
BEGIN
  SET XACT_ABORT ON;
  
  BEGIN TRAN;
  
  INSERT INTO dbo.NaglowkiDow (Rodzaj) VALUES (@Rodzaj);
  
  SELECT @DowId = SCOPE_IDENTITY();
  
  INSERT INTO dbo.PozycjeDow (DowId, TowarId, Ilosc)
  SELECT @DowId, p.TowarId, p.Ilosc
  FROM @Pozycje p;

  UPDATE t SET
    t.Stan = t.Stan + CASE @Rodzaj WHEN 'P' THEN 1 WHEN 'R' THEN -1 ELSE 0 END * p.Ilosc
  FROM dbo.Towary t
  JOIN @Pozycje p ON p.TowarId = t.TowarId;
    
  UPDATE n SET 
    n.IloscRazem = (SELECT SUM(p.Ilosc) FROM @Pozycje p),
    n.NumerDow =   ISNULL((SELECT MAX(n.NumerDow)+1 FROM dbo.NaglowkiDow n),1)
  FROM dbo.NaglowkiDow n
  WHERE n.DowId = @DowId;

  COMMIT TRAN;
END;
GO


IF OBJECT_ID('dbo.WstawDowodMag') IS NOT NULL DROP PROCEDURE dbo.WstawDowodMag;
GO
CREATE PROCEDURE dbo.WstawDowodMag 
  @Rodzaj varchar(2), 
  @Pozycje TPozycjeDow READONLY,
  @DowId int OUTPUT
AS 
BEGIN  
  BEGIN TRAN;-- TRANSAKCJA NA ZEWN¥TRZ TRY
  BEGIN TRY
    INSERT INTO dbo.NaglowkiDow (Rodzaj) VALUES (@Rodzaj);
    
    SELECT @DowId = SCOPE_IDENTITY();
        
    INSERT INTO dbo.PozycjeDow (DowId, TowarId, Ilosc)
    SELECT @DowId, p.TowarId, p.Ilosc
    FROM @Pozycje p;

    UPDATE t SET
      t.Stan = t.Stan + CASE @Rodzaj WHEN 'P' THEN 1 WHEN 'R' THEN -1 ELSE 0 END * p.Ilosc
    FROM dbo.Towary t
    JOIN @Pozycje p ON p.TowarId = t.TowarId;
      
    UPDATE n SET 
      n.IloscRazem = (SELECT SUM(p.Ilosc) FROM @Pozycje p),
      n.NumerDow =   ISNULL((SELECT MAX(n.NumerDow)+1 FROM dbo.NaglowkiDow n),1)
    FROM dbo.NaglowkiDow n
    WHERE n.DowId = @DowId;
  END TRY
  BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    PRINT ERROR_MESSAGE();
  END CATCH;
  IF @@TRANCOUNT > 0 COMMIT TRAN;
END;
GO


IF OBJECT_ID('dbo.WstawDowodMag') IS NOT NULL DROP PROCEDURE dbo.WstawDowodMag;
GO
CREATE PROCEDURE dbo.WstawDowodMag 
  @Rodzaj varchar(2), 
  @Pozycje TPozycjeDow READONLY,
  @DowId int OUTPUT
AS 
BEGIN  
  BEGIN TRAN;-- TRANSAKCJA NA ZEWN¥TRZ TRY
  BEGIN TRY
    INSERT INTO dbo.NaglowkiDow (Rodzaj) VALUES (@Rodzaj);
    
    SELECT @DowId = SCOPE_IDENTITY();
        
    INSERT INTO dbo.PozycjeDow (DowId, TowarId, Ilosc)
    SELECT @DowId, p.TowarId, p.Ilosc
    FROM @Pozycje p;

    UPDATE t SET
      t.Stan = t.Stan + CASE @Rodzaj WHEN 'P' THEN 1 WHEN 'R' THEN -1 ELSE 0 END * p.Ilosc
    FROM dbo.Towary t
    JOIN @Pozycje p ON p.TowarId = t.TowarId;
      
    UPDATE n SET 
      n.IloscRazem = (SELECT SUM(p.Ilosc) FROM @Pozycje p),
      n.NumerDow =   ISNULL((SELECT MAX(n.NumerDow)+1 FROM dbo.NaglowkiDow n),1)
    FROM dbo.NaglowkiDow n
    WHERE n.DowId = @DowId;
  END TRY
  BEGIN CATCH
    THROW; -- Ÿle!!!
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
  END CATCH;
  IF @@TRANCOUNT > 0 COMMIT TRAN;
END;
GO


IF OBJECT_ID('dbo.WstawDowodMag') IS NOT NULL DROP PROCEDURE dbo.WstawDowodMag;
GO
CREATE PROCEDURE dbo.WstawDowodMag 
  @Rodzaj varchar(2), 
  @Pozycje TPozycjeDow READONLY,
  @DowId int OUTPUT
AS 
BEGIN  
  DECLARE @TranCnt int = @@TRANCOUNT;
  DECLARE @SavePoint varchar(40) SET @SavePoint = REPLACE(CONVERT(VARCHAR(36),NEWID()),'-','');

  -- zacznij transakcjê tylko wtedy, gdy ktoœ inny jej nie zacz¹³
  IF @TranCnt = 0 BEGIN TRAN; 
  SAVE TRAN @SavePoint; -- SAVEPOINT bezwarunkowo

    BEGIN TRY
      INSERT INTO dbo.NaglowkiDow (Rodzaj) VALUES (@Rodzaj);
    
      SELECT @DowId = SCOPE_IDENTITY();
        
      INSERT INTO dbo.PozycjeDow (DowId, TowarId, Ilosc)
      SELECT @DowId, p.TowarId, p.Ilosc
      FROM @Pozycje p;

      UPDATE t SET
        t.Stan = t.Stan + CASE @Rodzaj WHEN 'P' THEN 1 WHEN 'R' THEN -1 ELSE 0 END * p.Ilosc
      FROM dbo.Towary t
      JOIN @Pozycje p ON p.TowarId = t.TowarId;
      
      UPDATE n SET 
        n.IloscRazem = (SELECT SUM(p.Ilosc) FROM @Pozycje p),
        n.NumerDow =   ISNULL((SELECT MAX(n.NumerDow)+1 FROM dbo.NaglowkiDow n),1)
      FROM dbo.NaglowkiDow n
      WHERE n.DowId = @DowId;
    END TRY
    BEGIN CATCH
      -- wycofaj transakcjê tylko wtedy, gdy j¹ zacz¹³eœ. Na wszelki wypadek sprawdŸ, czy w ogóle jeszcze j¹ masz.
      IF @TranCnt = 0 AND @@TRANCOUNT > 0 ROLLBACK TRAN;
      THROW; 
      RETURN -1; -- to ju¿ nie ma sensu
    END CATCH;

  IF @TranCnt = 0 COMMIT TRAN;
  RETURN 0;
END;
GO
IF OBJECT_ID('dbo.WstawZamowienie') IS NOT NULL DROP PROCEDURE dbo.WstawZamowienie  
GO
CREATE PROCEDURE dbo.WstawZamowienie @ZamId int, @Pozycje TPozycjeDow READONLY
AS
BEGIN
  DECLARE @DowId int, @Return int = 0;
  
  BEGIN TRAN;

  EXEC @Return = dbo.WstawDowodMag @Rodzaj = 'R', @Pozycje = @Pozycje, @DowId = @DowId OUTPUT;
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
INSERT INTO @Pozycje (TowarId, Ilosc) VALUES ('T0',9),('T1',9),('T2',9),('T3',2);
EXEC dbo.WstawZamowienie 88, @Pozycje;
SELECT @@TRANCOUNT;

SELECT * FROM dbo.Zamowienia WHERE ZamId = 88;
SELECT * FROM dbo.NaglowkiDow WHERE DowId = (SELECT DowId FROM dbo.Zamowienia WHERE ZamId = 88);
SELECT * FROM dbo.PozycjeDow WHERE DowId = (SELECT DowId FROM dbo.Zamowienia WHERE ZamId = 88);
GO
IF @@TRANCOUNT > 0 ROLLBACK;


IF OBJECT_ID('dbo.WstawZamowienie') IS NOT NULL DROP PROCEDURE dbo.WstawZamowienie  
GO
CREATE PROCEDURE dbo.WstawZamowienie @ZamId int, @Pozycje TPozycjeDow READONLY
AS
BEGIN
  DECLARE @DowId int, @Return int = 0;
  -- jak mamy w œrodku TRHOW, to musimy konsekwentnie stosowaæ TRY..CATCH
  BEGIN TRAN;
  
    BEGIN TRY
      EXEC dbo.WstawDowodMag @Rodzaj = 'R', @Pozycje = @Pozycje, @DowId = @DowId OUTPUT;
      INSERT INTO dbo.Zamowienia (ZamId, DowId) VALUES (@ZamId, @DowId);
    END TRY
    BEGIN CATCH
      PRINT ERROR_MESSAGE()
    END CATCH;

  COMMIT TRAN;
  RETURN 0;
END;
GO


DECLARE @Pozycje TPozycjeDow;
INSERT INTO @Pozycje (TowarId, Ilosc) VALUES ('T0',9),('T1',9),('T2',9),('T3',2);
EXEC dbo.WstawZamowienie 88, @Pozycje;
SELECT @@TRANCOUNT;

SELECT * FROM dbo.Zamowienia WHERE ZamId = 88;
SELECT * FROM dbo.NaglowkiDow WHERE DowId = (SELECT DowId FROM dbo.Zamowienia WHERE ZamId = 88);
SELECT * FROM dbo.PozycjeDow WHERE DowId = (SELECT DowId FROM dbo.Zamowienia WHERE ZamId = 88);
GO
IF @@TRANCOUNT > 0 ROLLBACK;
