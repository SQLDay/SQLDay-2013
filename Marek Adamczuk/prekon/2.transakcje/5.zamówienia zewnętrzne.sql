USE Magazyn;
GO
SET NOCOUNT ON;
GO
IF OBJECT_ID('dbo.WstawZamowienie') IS NOT NULL DROP PROCEDURE dbo.WstawZamowienie;
GO
CREATE PROCEDURE dbo.WstawZamowienie @ZamId int, @Pozycje TPozycjeDow READONLY
AS
-- Jak si� wstawi zam�wienie, to ma si� te� zrealizowa�!
BEGIN
  SET NOCOUNT ON;
  -- ta procedura zagnie�d�a transakcj�. Zobaczymy, jakie to problemy rodzi.
  DECLARE @DowId int;
  
  BEGIN TRAN;
    -- Zarejestruj rozch�d - realizacja zam�wienia
    EXEC dbo.WstawDowodMag @Rodzaj = 'R', @Pozycje = @Pozycje, @DowId = @DowId OUTPUT;
    IF @@ERROR <> 0 GOTO END_ROLLBACK;
    
    -- Zarejestruj powi�zanie numeru zam�wienia z wystawionym rozchodem
    INSERT INTO dbo.Zamowienia (ZamId, DowId) VALUES (@ZamId, @DowId);
    IF @@ERROR <> 0 GOTO END_ROLLBACK;
  
  COMMIT TRAN;
  RETURN 0;
  
  END_ROLLBACK:
  ROLLBACK TRAN;
  RETURN -1;
END;
GO
-- weryfikacja stanu, ma starczy�!
SELECT * FROM dbo.Towary WHERE TowarId IN ('T0','T2') -- stany 5, 8
--
DECLARE @Pozycje TPozycjeDow;
INSERT INTO @Pozycje (TowarId, Ilosc) VALUES ('T0',2),('T2',2)
EXEC dbo.WstawZamowienie @ZamId = 1, @Pozycje = @Pozycje
GO
SELECT * FROM dbo.Towary WHERE TowarId IN ('T1','T3') -- stany 0, 0 ma odbi� kontrola stan�w
DECLARE @Pozycje TPozycjeDow;
INSERT INTO @Pozycje (TowarId, Ilosc) VALUES ('T1',2),('T3',2)
EXEC dbo.WstawZamowienie @ZamId = 2, @Pozycje = @Pozycje
GO
SELECT * FROM dbo.Zamowienia WHERE ZamId = 1;
SELECT * FROM dbo.Zamowienia WHERE ZamId = 2;
GO
select * from dbo.NaglowkiDow;
GO