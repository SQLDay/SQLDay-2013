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
  
  -- nag³ówek 
  INSERT INTO dbo.NaglowkiDow (Rodzaj) VALUES (@Rodzaj);
  SELECT @DowId = SCOPE_IDENTITY();
  
  -- pozycje
  INSERT INTO dbo.PozycjeDow (DowId, TowarId, Ilosc)
  SELECT @DowId, p.TowarId, p.Ilosc
  FROM @Pozycje p;
  
  -- uaktualnienie stanu magazynowego
  UPDATE t SET
    t.Stan = t.Stan + CASE @Rodzaj WHEN 'P' THEN 1 WHEN 'R' THEN -1 ELSE 0 END * p.Ilosc
  FROM dbo.Towary t
  JOIN @Pozycje p ON p.TowarId = t.TowarId;
   
  -- uaktualnienie agregatów na nag³ówku dowodu mag  
  UPDATE n SET 
    n.IloscRazem = (SELECT SUM(p.Ilosc) FROM @Pozycje p),
    n.NumerDow =   ISNULL((SELECT MAX(n.NumerDow)+1 FROM dbo.NaglowkiDow n),1)
  FROM dbo.NaglowkiDow n
  WHERE n.DowId = @DowId;

  COMMIT TRAN;
END;
GO
