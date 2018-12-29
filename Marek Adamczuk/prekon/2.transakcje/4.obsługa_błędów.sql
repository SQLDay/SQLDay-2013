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
-- Dowód ma siê wstawiæ w ca³oœci albo wcale!
BEGIN
  BEGIN TRAN;
  
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
  
  COMMIT TRAN;
  RETURN 0;
  
  END_ROLLBACK:
  ROLLBACK TRAN; 
END;
GO





