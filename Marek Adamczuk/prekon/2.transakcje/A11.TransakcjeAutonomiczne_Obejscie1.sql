IF OBJECT_ID('dbo.WstawDowodMag') IS NOT NULL DROP PROCEDURE dbo.WstawDowodMag;
GO
CREATE PROCEDURE dbo.WstawDowodMag 
  @Rodzaj varchar(2), 
  @Pozycje TPozycjeDow READONLY,
  @DowId int OUTPUT
AS 
BEGIN
  -- upewnij siê czy wchodz¹c do procedury jesteœ ju¿ w transakcji;
  DECLARE @TranCnt int = @@TRANCOUNT;
  DECLARE @SavePoint varchar(40) SET @SavePoint = REPLACE(CONVERT(VARCHAR(36),NEWID()),'-','');

  DECLARE @Przekroczenia TABLE(
  DowId int,
  TowarId varchar(2),
  Stan int);

  -- zacznij transakcjê tylko wtedy, gdy ktoœ inny jej nie zacz¹³
  IF @TranCnt = 0 BEGIN TRAN; 
  SAVE TRAN @SavePoint; -- SAVEPOINT bezwarunkowo
  
  INSERT INTO dbo.NaglowkiDow (Rodzaj) VALUES (@Rodzaj);
  IF @@ERROR<>0 GOTO END_ROLLBACK;
    
  SELECT @DowId = SCOPE_IDENTITY();
  IF @@ERROR<>0 GOTO END_ROLLBACK;
  
  INSERT INTO dbo.PozycjeDow (DowId, TowarId, Ilosc)
  SELECT @DowId, p.TowarId, p.Ilosc
  FROM @Pozycje p;
  IF @@ERROR<>0 GOTO END_ROLLBACK;
  
  -- tu ju¿ nas check nie zatrzyma
  UPDATE t SET
    t.Stan = t.Stan + CASE @Rodzaj WHEN 'P' THEN 1 WHEN 'R' THEN -1 ELSE 0 END * p.Ilosc
  FROM dbo.Towary t
  JOIN @Pozycje p ON p.TowarId = t.TowarId
  IF @@ERROR<>0 GOTO END_ROLLBACK;

  /* UWAGA!!! ZMIANA!!! Tu musimy wstawiæ do czegoœ nieczu³ego na rollback!!!*/
  -- musimy zrobiæ to sami 
  INSERT INTO @Przekroczenia (DowId, TowarId, Stan)
  SELECT @DowId, t.TowarId, t.Stan FROM dbo.Towary t
  JOIN @Pozycje p ON p.TowarId = t.TowarId
  WHERE t.Stan < 0
  IF @@ERROR<>0 OR @@ROWCOUNT > 0 BEGIN
    RAISERROR ('B³¹d kontroli stanów!',16,1);
    GOTO END_ROLLBACK;
  END;
  
  UPDATE n SET 
    n.IloscRazem = (SELECT SUM(p.Ilosc) FROM @Pozycje p),
    n.NumerDow =   ISNULL((SELECT MAX(n.NumerDow)+1 FROM dbo.NaglowkiDow n),1)
  FROM dbo.NaglowkiDow n
  WHERE n.DowId = @DowId;
  IF @@ERROR<>0 GOTO END_ROLLBACK;
  
  -- zatwierdŸ transakcjê tylko wtedy, gdy j¹ zacz¹³eœ. Jeœli to ktoœ inny, to niech on siê o to martwi
  IF @TranCnt = 0 COMMIT TRAN;
  RETURN 0;
  
  END_ROLLBACK:
  IF @@TRANCOUNT > 0 ROLLBACK TRAN @SavePoint;
  -- wycofaj transakcjê tylko wtedy, gdy j¹ zacz¹³eœ. Na wszelki wypadek sprawdŸ, czy w ogóle jeszcze j¹ masz.
  IF @TranCnt = 0 AND @@TRANCOUNT > 0 ROLLBACK TRAN;
  -- To prze¿y³o rollback!
  INSERT INTO dbo.Przekroczenia (DowId, TowarId, Stan)
  SELECT p.DowId, p.TowarId, p.Stan FROM @Przekroczenia p;
  RETURN -1; 
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
EXEC dbo.WstawDowodMag @Rodzaj = 'R', @Pozycje = @Pozycje, @DowId = 0;
GO
SELECT * FROM dbo.Przekroczenia;
GO
-- tylko co w przypadku, gdy tracimy kontakt z rollbackiem :(
DELETE FROM dbo.Przekroczenia;
DECLARE @Pozycje TPozycjeDow;
INSERT INTO @Pozycje (TowarId, Ilosc) VALUES ('T0',9),('T1',9),('T2',9),('T3',2);
EXEC dbo.WstawZamowienie 77, @Pozycje;
GO
SELECT * FROM dbo.Zamowienia WHERE ZamId = 77 -- tu jest OK!
SELECT * FROM Przekroczenia -- nie ma! Zewnêtrzna transakcja zrollbackowa³a :(
