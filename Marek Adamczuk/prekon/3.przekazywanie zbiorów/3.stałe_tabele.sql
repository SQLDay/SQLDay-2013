IF EXISTS (SELECT 1 FROM sys.sequences s WHERE s.name = 'NumeryFaktur') begin
  drop sequence dbo.NumeryFaktur
  create sequence dbo.NumeryFaktur start with 1 increment by 1
end;
GO
-- w tabeli mamy ju¿ dane. Ustaw prawid³owo wartoœæ startow¹ sekwencji
declare @maxFaktId int, @sql nvarchar(max);
select @maxFaktId = max(f.FaktId)+1 FROM dbo.Faktury f
set @sql = concat('alter sequence dbo.NumeryFaktur restart with ',@maxFaktId)
exec (@sql);
GO


if object_id('dbo.tmp_Faktury') is not null drop table dbo.tmp_Faktury
GO
create table dbo.tmp_Faktury (
   _session_id_ int constraint DF_tmp_Faktury_session_id_ default @@spid,
   FaktId	int,
   KlientId	int,
   Data	 datetime,
   Uwagi varchar(800),
   NumerFa varchar(20)
   );
GO
create clustered index tmp_Faktury on tmp_Faktury(_session_id_)
GO
if object_id('dbo.tmp_PozycjeFaktur') is not null drop table dbo.tmp_PozycjeFaktur
GO
create table dbo.tmp_PozycjeFaktur (
_session_id_ int constraint DF_tmp_PozycjeFaktur_session_id_ default @@spid,
FaktId	int,
NrPoz	int,
TowarId	int,
Ilosc	int,
Cena	money)
GO
create clustered index tmp_PozycjeFaktur on tmp_PozycjeFaktur(_session_id_)
GO
IF OBJECT_ID('dbo.modyfikuj_faktury') IS NOT NULL DROP PROCEDURE dbo.modyfikuj_faktury;
GO
CREATE PROCEDURE dbo.modyfikuj_faktury
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @TranCnt int = @@TRANCOUNT;
  DECLARE @SavePoint varchar(40) SET @SavePoint = REPLACE(CONVERT(VARCHAR(36),NEWID()),'-','');
  IF @TranCnt = 0 BEGIN TRAN; 
  SAVE TRAN @SavePoint;
  
  DECLARE @nowe_faktury TABLE (FaktId int, tmpFaktId int);

  -- nadajemy nowe numery. Przyjmujemy, ¿e FaktId <= 0 w tmp to nowe rekordy
  INSERT INTO @nowe_faktury(FaktId, tmpFaktId)
  SELECT 
  NEXT VALUE FOR dbo.NumeryFaktur,
  t.FaktId
  FROM dbo.tmp_Faktury t
  WHERE t._session_id_ = @@SPID AND t.FaktId <= 0;
  IF @@ERROR <> 0 GOTO END_ROLLBACK;

  -- wstaw nowe faktury
  INSERT INTO dbo.Faktury (FaktId, KlientId, Data, Uwagi, NumerFa)
  SELECT 
  n.FaktId, t.KlientId, t.Data, t.Uwagi, t.NumerFa From dbo.tmp_Faktury t  
  JOIN @nowe_faktury n on t.FaktId = n.tmpFaktId WHERE t._session_id_ = @@SPID;
  IF @@ERROR <> 0 GOTO END_ROLLBACK;

  -- Nadpisz istniej¹ce faktury
  UPDATE f
    SET 
    f.KlientId = t.KlientId,
    f.Data = t.Data,
    f.Uwagi = t.Uwagi,
    f.NumerFa = t.NumerFa
  FROM dbo.tmp_Faktury t 
  INNER LOOP JOIN dbo.Faktury f ON f.FaktId = t.FaktId WHERE t._session_id_ = @@SPID;
  IF @@ERROR <> 0 GOTO END_ROLLBACK;

  -- Nadpisz interfejsy nowymi id-kami faktur
  UPDATE t
    SET t.FaktId = n.FaktId
  FROM dbo.tmp_Faktury t 
  JOIN @nowe_faktury n on t.FaktId = n.tmpFaktId
  WHERE t._session_id_ = @@SPID;
  IF @@ERROR <> 0 GOTO END_ROLLBACK;

  UPDATE t
  SET t.FaktId = n.FaktId
  FROM dbo.tmp_PozycjeFaktur t 
  JOIN @nowe_faktury n on t.FaktId = n.tmpFaktId
  WHERE t._session_id_ = @@SPID;
  IF @@ERROR <> 0 GOTO END_ROLLBACK;

  -- Pozycje: trochê brutalnie. Wyrzuæ i wrzuæ wszystko. Mo¿na to zrobiæ bardziej elegancko
  DELETE FROM p
  FROM dbo.PozycjeFaktur p 
  WHERE FaktId in (SELECT f.FaktId FROM dbo.tmp_Faktury f WHERE f.FaktId = p.FaktId AND f._session_id_ = @@SPID);
  IF @@ERROR <> 0 GOTO END_ROLLBACK;

  INSERT INTO dbo.PozycjeFaktur (FaktId, NrPoz, TowarId, Ilosc, Cena)
  SELECT t.FaktId, t.NrPoz, t.TowarId, t.Ilosc, t.Cena
  FROM dbo.tmp_PozycjeFaktur t WHERE t._session_id_ = @@SPID;
  IF @@ERROR <> 0 GOTO END_ROLLBACK;
  
  IF @TranCnt = 0 AND @@TRANCOUNT > 0 COMMIT TRAN;
  RETURN 0;

  END_ROLLBACK:
  IF @@TRANCOUNT > 0 ROLLBACK TRAN @SavePoint;
  IF @TranCnt = 0 AND @@TRANCOUNT > 0 ROLLBACK TRAN;
  RETURN -1; 
end;
GO
if object_id('dbo.wyczysc_interfejs_faktur') IS NOT NULL DROP PROCEDURE dbo.wyczysc_interfejs_faktur;
GO
CREATE PROCEDURE dbo.wyczysc_interfejs_faktur
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @TranCnt int = @@TRANCOUNT;
  DECLARE @SavePoint varchar(40) SET @SavePoint = REPLACE(CONVERT(VARCHAR(36),NEWID()),'-','');
  IF @TranCnt = 0 BEGIN TRAN; 
  SAVE TRAN @SavePoint;
  
  DELETE FROM dbo.tmp_Faktury WHERE _session_id_ = @@spid;  
  IF @@ERROR <> 0 GOTO END_ROLLBACK;

  DELETE FROM dbo.tmp_PozycjeFaktur WHERE _session_id_ = @@spid;
  IF @@ERROR <> 0 GOTO END_ROLLBACK;

  IF @TranCnt = 0 AND @@TRANCOUNT > 0 COMMIT TRAN;
  RETURN 0;
  END_ROLLBACK:
  IF @@TRANCOUNT > 0 ROLLBACK TRAN @SavePoint;
  IF @TranCnt = 0 AND @@TRANCOUNT > 0 ROLLBACK TRAN;
  RETURN -1; 

END;
GO

--select * from tmp_Faktury
--EXEC wyczysc_interfejs_faktur
-- wstawimy jednoczeœnie 10 faktur
EXEC wyczysc_interfejs_faktur
GO
insert into dbo.tmp_Faktury (FaktId, KlientId, Data, Uwagi, NumerFa)
select top 10 -KlientId as FaktId, 
k.KlientId, 
convert(date, getdate()) Data,
'Faktura klienta '+k.NazwaKlienta Uwagi,
'<NEW>' NumerFa
from dbo.klienci k order by newid()
GO
insert into dbo.tmp_PozycjeFaktur(FaktId,NrPoz,TowarId,Ilosc,Cena)
SELECT t.FaktId, 
  row_number() over(partition by t.FaktId order by tow.TowarId) NrPoz,
  tow.TowarId,
  abs(checksum(newid()))%10+1 Ilosc, -- do 10
  (abs(checksum(newid()))%10000+1)/$100 Cena -- do 100
FROM tmp_Faktury t 
CROSS APPLY (SELECT TOP 10 tow.TowarId FROM dbo.Towary tow ORDER BY NewId()) tow
WHERE t._session_id_ = @@SPID;
GO
exec dbo.modyfikuj_faktury
GO
/*
PROBLEMY
1. Dba³oœæ o czyszczenie interfejsu
2. Trzeba pamiêtaæ o warunku wycinaj¹cym nasze dane (tym na @@SPID)
3. SQL Server traktuje tabele tmp_ jak zwyk³e tabele z danymi. np. czyszczenie do 0 odbudowuje statystyki.
4. Wszystkie operacje potencjalnie siê blokuj¹ (normalna transakcja)

KORZYŒCI
1. Nie przekazujemy jawnie parametrów
2. Naj³atwiejsza przy dok³adaniu nowych kolumn do tabel. Minimalna interwencja i do zast¹pienia przez autogenerator
*/