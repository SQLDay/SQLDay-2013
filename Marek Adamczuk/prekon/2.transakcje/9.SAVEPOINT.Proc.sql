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
  -- upewnij siê czy wchodz¹c do procedury jesteœ ju¿ w transakcji;
  DECLARE @TranCnt int = @@TRANCOUNT;
  DECLARE @SavePoint varchar(40) SET @SavePoint = REPLACE(CONVERT(VARCHAR(36),NEWID()),'-','');

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
  
  -- zatwierdŸ transakcjê tylko wtedy, gdy j¹ zacz¹³eœ. Jeœli to ktoœ inny, to niech on siê o to martwi
  IF @TranCnt = 0 COMMIT TRAN;
  RETURN 0;
  
  END_ROLLBACK:
  IF @@TRANCOUNT > 0 ROLLBACK TRAN @SavePoint;
  -- wycofaj transakcjê tylko wtedy, gdy j¹ zacz¹³eœ. Na wszelki wypadek sprawdŸ, czy w ogóle jeszcze j¹ masz.
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
  -- Ÿle! ale i tak damy radê siê wycofaæ 
  EXEC /*@Return = */ dbo.WstawDowodMag @Rodzaj = 'R', @Pozycje = @Pozycje, @DowId = @DowId OUTPUT;--B£¥D Brak zwróconej wartoœci!
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
EXEC dbo.WstawZamowienie @ZamId = 66, @Pozycje = @Pozycje;
GO
SELECT * FROM dbo.Zamowienia WHERE ZamId = 66;
SELECT * FROM dbo.NaglowkiDow WHERE DowId = (SELECT DowId FROM dbo.Zamowienia WHERE ZamId = 66);
SELECT * FROM dbo.PozycjeDow WHERE DowId = (SELECT DowId FROM dbo.Zamowienia WHERE ZamId = 66);
GO
