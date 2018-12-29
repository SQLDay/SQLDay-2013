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




IF OBJECT_ID('dbo.modyfikuj_faktury_tempTab') IS NOT NULL DROP PROCEDURE dbo.modyfikuj_faktury_tempTab;
GO
CREATE PROCEDURE dbo.modyfikuj_faktury_tempTab
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @TranCnt int = @@TRANCOUNT;
  DECLARE @SavePoint varchar(40) SET @SavePoint = REPLACE(CONVERT(VARCHAR(36),NEWID()),'-','');
  IF @TranCnt = 0 BEGIN TRAN; 
  SAVE TRAN @SavePoint;
  
  DECLARE @nowe_faktury TABLE (FaktId int, tmpFaktId int);

  SELECT * FROM Kaszanka;

  -- nadajemy nowe numery. Przyjmujemy, ¿e FaktId <= 0 w tmp to nowe rekordy
  INSERT INTO @nowe_faktury(FaktId, tmpFaktId)
  SELECT 
  NEXT VALUE FOR dbo.NumeryFaktur,
  t.FaktId
  FROM #tmp_Faktury t
  WHERE t.FaktId <= 0;
  IF @@ERROR <> 0 GOTO END_ROLLBACK;

  -- wstaw nowe faktury
  INSERT INTO dbo.Faktury (FaktId, KlientId, Data, Uwagi, NumerFa)
  SELECT 
  n.FaktId, t.KlientId, t.Data, t.Uwagi, t.NumerFa 
  From #tmp_Faktury t  
  JOIN @nowe_faktury n on t.FaktId = n.tmpFaktId;
  IF @@ERROR <> 0 GOTO END_ROLLBACK;

  -- Nadpisz istniej¹ce faktury
  UPDATE f
    SET 
    f.KlientId = t.KlientId,
    f.Data = t.Data,
    f.Uwagi = t.Uwagi,
    f.NumerFa = t.NumerFa
  FROM dbo.Faktury f 
  JOIN #tmp_Faktury t ON f.FaktId = t.FaktId;
  IF @@ERROR <> 0 GOTO END_ROLLBACK;

  -- Nadpisz interfejsy nowymi id-kami faktur
  UPDATE t
    SET t.FaktId = n.FaktId
  FROM #tmp_Faktury t 
  JOIN @nowe_faktury n on t.FaktId = n.tmpFaktId;
  IF @@ERROR <> 0 GOTO END_ROLLBACK;

  UPDATE t
  SET t.FaktId = n.FaktId
  FROM #tmp_PozycjeFaktur t
  JOIN @nowe_faktury n on t.FaktId = n.tmpFaktId;
  IF @@ERROR <> 0 GOTO END_ROLLBACK;

  -- Pozycje: trochê brutalnie. Wyrzuæ i wrzuæ wszystko. Mo¿na to zrobiæ bardziej elegancko
  DELETE FROM p
  FROM dbo.PozycjeFaktur p
  WHERE FaktId in (SELECT f.FaktId FROM #tmp_Faktury f WHERE f.FaktId = p.FaktId);
  IF @@ERROR <> 0 GOTO END_ROLLBACK;

  INSERT INTO dbo.PozycjeFaktur (FaktId, NrPoz, TowarId, Ilosc, Cena)
  SELECT t.FaktId, t.NrPoz, t.TowarId, t.Ilosc, t.Cena
  FROM #tmp_PozycjeFaktur t;
  IF @@ERROR <> 0 GOTO END_ROLLBACK;
  
  IF @TranCnt = 0 AND @@TRANCOUNT > 0 COMMIT TRAN;
  RETURN 0;

  END_ROLLBACK:
  IF @@TRANCOUNT > 0 ROLLBACK TRAN @SavePoint;
  IF @TranCnt = 0 AND @@TRANCOUNT > 0 ROLLBACK TRAN;
  RETURN -1; 
end;
GO

select * from sys.sql_expression_dependencies where referencing_id = OBJECT_ID('dbo.modyfikuj_faktury_tempTab')



-- wstawimy jednoczeœnie 10 faktur
GO
if object_id('tempdb.dbo.#tmp_Faktury') is not null drop table #tmp_Faktury;
if object_id('tempdb.dbo.#tmp_PozycjeFaktur') is not null drop table #tmp_PozycjeFaktur;
GO
select top 10 -KlientId as FaktId, 
k.KlientId, 
convert(date, getdate()) Data,
'Faktura klienta '+k.NazwaKlienta Uwagi,
'<NEW-TEMPTAB>' NumerFa
into #tmp_Faktury
from dbo.klienci k order by newid()
GO
SELECT t.FaktId, 
  row_number() over(partition by t.FaktId order by tow.TowarId) NrPoz,
  tow.TowarId,
  abs(checksum(newid()))%10+1 Ilosc, -- do 10
  (abs(checksum(newid()))%10000+1)/$100 Cena -- do 100
into #tmp_PozycjeFaktur
FROM #tmp_Faktury t 
CROSS APPLY (SELECT TOP 10 tow.TowarId FROM Towary tow ORDER BY NewId()) tow;
GO
exec dbo.modyfikuj_faktury_tempTab;
GO
select * from #tmp_Faktury t
GO
select f.* from dbo.faktury f join #tmp_Faktury t on f.FaktId = t.FaktId
GO
/*
problemy
1. Trzeba utworzyæ obiekty tymczasowe przed wywo³aniem procedury. B³¹d braku obiektu = zostaje transakcja!!!
2. Procedura u¿ywa obiektów tymczasowych nie stworzonych przez siebie - gwarantowane rekompilacje
3. Ryzyko zderzenia nazw obiektów
*/

begin try
  exec dbo.modyfikuj_faktury_tempTab;
end try
begin catch
  select error_message()
end catch