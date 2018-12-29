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
  -- upewnij si� czy wchodz�c do procedury jeste� ju� w transakcji;
  DECLARE @TranCnt int = @@TRANCOUNT;

  -- zacznij transakcj� tylko wtedy, gdy kto� inny jej nie zacz��
  IF @TranCnt = 0 BEGIN TRAN;

  /*STANDARD*/
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
    n.NumerDow =   ISNULL((SELECT MAX(n.NumerDow)+1 FROM dbo.NaglowkiDow n),1)
  FROM dbo.NaglowkiDow n
  WHERE n.DowId = @DowId;
  IF @@ERROR<>0 GOTO END_ROLLBACK;
  /*END STANDARD*/

  -- zatwierd� transakcj� tylko wtedy, gdy j� zacz��e(a)�. Je�li to kto� inny, to niech on si� o to martwi
  IF @TranCnt = 0 COMMIT TRAN;
  RETURN 0;
  
  END_ROLLBACK:
  -- wycofaj transakcj� tylko wtedy, gdy j� zacz��e(a)�. Na wszelki wypadek sprawd�, czy w og�le jeszcze j� masz.
  IF @TranCnt = 0 AND @@TRANCOUNT > 0 ROLLBACK TRAN; 
  RETURN -1;
END;
GO
IF OBJECT_ID('dbo.WstawZamowienie') IS NOT NULL DROP PROCEDURE dbo.WstawZamowienie;
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
SELECT * FROM dbo.Towary; -- podgl�d stan�w

DECLARE @Pozycje TPozycjeDow;
INSERT INTO @Pozycje (TowarId, Ilosc) VALUES ('T1',2),('T3',2);
EXEC dbo.WstawZamowienie @ZamId = 55, @Pozycje = @Pozycje;
GO
SELECT * FROM dbo.Zamowienia WHERE ZamId = 55;
GO
-- a co je�li zaczynaj�cy transakcj� post�pi �le?
IF OBJECT_ID('dbo.WstawZamowienie') IS NOT NULL DROP PROCEDURE dbo.WstawZamowienie;
GO
CREATE PROCEDURE dbo.WstawZamowienie @ZamId int, @Pozycje TPozycjeDow READONLY
AS
BEGIN
  DECLARE @DowId int, @Return int = 0;
  
  BEGIN TRAN;
  
  EXEC /*@Return = */ dbo.WstawDowodMag @Rodzaj = 'R', @Pozycje = @Pozycje, @DowId = @DowId OUTPUT;
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
EXEC dbo.WstawZamowienie @ZamId = 55, @Pozycje = @Pozycje;
GO
-- B��d zosta� zg�oszony, ale zewn�trzna transakcja zacommitowa�a!
SELECT * FROM dbo.Zamowienia WHERE ZamId = 55;
SELECT * FROM dbo.NaglowkiDow WHERE DowId = (SELECT DowId FROM dbo.Zamowienia WHERE ZamId = 55);
SELECT * FROM dbo.PozycjeDow WHERE DowId = (SELECT DowId FROM dbo.Zamowienia WHERE ZamId = 55);
GO
