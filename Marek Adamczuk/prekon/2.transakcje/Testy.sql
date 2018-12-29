USE Magazyn;
GO
SET NOCOUNT ON;
GO
PRINT 'Czyszczenie'
DELETE FROM dbo.Zamowienia;
DELETE FROM dbo.PozycjeDow;
INSERT dbo.NaglowkiDow (Rodzaj) SELECT 'P'
DELETE FROM dbo.NaglowkiDow;
DELETE FROM dbo.Towary;
DBCC CHECKIDENT('dbo.NaglowkiDow',RESEED,0)
GO
PRINT 'Inicjacja kartoteki towarów'
INSERT INTO dbo.Towary (TowarId)
VALUES ('T0'),('T1'),('T2'),('T3');
GO
PRINT '1.wstawiamy przychód, który ma siê udaæ'
DECLARE @Poz TPozycjeDow, @DowId int;
INSERT INTO @Poz (TowarId, Ilosc)
VALUES ('T0', 5), ('T2', 8);
EXEC dbo.WstawDowodMag @Rodzaj = 'P', @Pozycje = @Poz, @DowId = @DowId OUTPUT;
SELECT @DowId AS DowId;
GO
PRINT '2.to ma SIÊ NIE UDAÆ! nie ma towartu T5'
DECLARE @Poz TPozycjeDow, @DowId int;
INSERT INTO @Poz (TowarId, Ilosc)
VALUES ('T3', 10), ('T5', 10);
EXEC dbo.WstawDowodMag @Rodzaj = 'P', @Pozycje = @Poz, @DowId = @DowId OUTPUT;
SELECT @DowId AS DowId;
GO
PRINT '3.to ma SIÊ NIE UDAÆ! Duplikacja towaru na pozycjach dowodu'
DECLARE @Poz TPozycjeDow, @DowId int;
INSERT INTO @Poz (TowarId, Ilosc)
VALUES ('T1', 1), ('T1', 1);
EXEC dbo.WstawDowodMag @Rodzaj = 'P', @Pozycje = @Poz, @DowId = @DowId OUTPUT;
SELECT @DowId AS DowId;
GO
PRINT '4.to ma SIÊ NIE UDAÆ! Przekroczenie stanu magazynowego'
DECLARE @Poz TPozycjeDow, @DowId int;
INSERT INTO @Poz (TowarId, Ilosc)
VALUES ('T0', 6), ('T2', 6);
EXEC dbo.WstawDowodMag @Rodzaj = 'R', @Pozycje = @Poz, @DowId = @DowId OUTPUT;
SELECT @DowId AS DowId;
GO
SELECT * FROM dbo.NaglowkiDow; -- tylko 1
SELECT * FROM dbo.PozycjeDow; -- tylko pozycje przychodu 1
SELECT * FROM dbo.Towary; -- odpowiednio 5, 0, 8, 0
GO
--SELECT @@TRANCOUNT; IF @@TRANCOUNT>0 ROLLBACK TRAN;
