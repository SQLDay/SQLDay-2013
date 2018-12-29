IF EXISTS (SELECT 1 FROM sys.sequences s WHERE s.name = 'NumeryFaktur') begin
  drop sequence dbo.NumeryFaktur
end;
create sequence dbo.NumeryFaktur start with 1 increment by 1;
GO
-- w tabeli mamy ju¿ dane. Ustaw prawid³owo wartoœæ startow¹ sekwencji
declare @maxFaktId int, @sql nvarchar(max);
select @maxFaktId = max(f.FaktId)+1 FROM dbo.Faktury f
set @sql = concat('alter sequence dbo.NumeryFaktur restart with ',@maxFaktId)
exec (@sql);
GO
if type_id('tFaktury') IS NULL 
create type tFaktury as table (
   FaktId	int,
   KlientId	int,
   Data	 datetime,
   Uwagi varchar(800),
   NumerFa varchar(20)
   );
GO
if type_id('tPozycjeFaktur') IS NULL 
create type tPozycjeFaktur as table(
  FaktId	int,
  NrPoz	int,
  TowarId	int, 
  Ilosc	int,
  Cena	money
  );
GO
IF OBJECT_ID('dbo.modyfikuj_faktury_tabType') IS NOT NULL DROP PROCEDURE dbo.modyfikuj_faktury_tabType;
GO
CREATE PROCEDURE dbo.modyfikuj_faktury_tabType 
  @tmp_Faktury tFaktury READONLY, 
  @tmp_PozycjeFaktur tPozycjeFaktur READONLY
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
  FROM @tmp_Faktury t
  WHERE t.FaktId <= 0;
  IF @@ERROR <> 0 GOTO END_ROLLBACK;

  -- wstaw nowe faktury
  INSERT INTO dbo.Faktury (FaktId, KlientId, Data, Uwagi, NumerFa)
  SELECT 
  n.FaktId, t.KlientId, t.Data, t.Uwagi, t.NumerFa 
  From @tmp_Faktury t  
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
  JOIN @tmp_Faktury t ON f.FaktId = t.FaktId;
  IF @@ERROR <> 0 GOTO END_ROLLBACK;

  -- Pozycje: trochê brutalnie. Wyrzuæ i wrzuæ wszystko. Mo¿na to zrobiæ bardziej elegancko
  DELETE FROM p
  FROM dbo.PozycjeFaktur p
  WHERE p.FaktId in (SELECT f.FaktId FROM @tmp_Faktury f);
  IF @@ERROR <> 0 GOTO END_ROLLBACK;

  INSERT INTO dbo.PozycjeFaktur (FaktId, NrPoz, TowarId, Ilosc, Cena)
  SELECT f.FaktId, t.NrPoz, t.TowarId, t.Ilosc, t.Cena
  FROM @tmp_PozycjeFaktur t
  JOIN @nowe_faktury f ON t.FaktId = f.tmpFaktId;
  IF @@ERROR <> 0 GOTO END_ROLLBACK;
  
  IF @TranCnt = 0 AND @@TRANCOUNT > 0 COMMIT TRAN;
  RETURN 0;

  END_ROLLBACK:
  IF @@TRANCOUNT > 0 ROLLBACK TRAN @SavePoint;
  IF @TranCnt = 0 AND @@TRANCOUNT > 0 ROLLBACK TRAN;
  RETURN -1; 
end;
GO

--select * from tmp_Faktury
--EXEC wyczysc_interfejs_faktur
-- wstawimy jednoczeœnie 10 faktur
GO
declare @tmp_Faktury tFaktury, @tmp_PozycjeFaktur tPozycjeFaktur;

insert into @tmp_Faktury (FaktId, KlientId, Data, Uwagi, NumerFa)
select top 10 -KlientId as FaktId, 
k.KlientId, 
convert(date, getdate()) Data,
'Faktura klienta '+k.NazwaKlienta Uwagi,
'<NEW-TABTYPE>' NumerFa
from dbo.klienci k order by newid()
insert into @tmp_PozycjeFaktur(FaktId,NrPoz,TowarId,Ilosc,Cena)
SELECT t.FaktId, 
  row_number() over(partition by t.FaktId order by tow.TowarId) NrPoz,
  tow.TowarId,
  abs(checksum(newid()))%10+1 Ilosc, -- do 10
  (abs(checksum(newid()))%10000+1)/$100 Cena -- do 100
FROM @tmp_Faktury t 
CROSS APPLY (SELECT TOP 10 tow.TowarId FROM dbo.Towary tow ORDER BY NewId()) tow;
exec dbo.modyfikuj_faktury_tabType @tmp_Faktury, @tmp_PozycjeFaktur;
GO

select * from Faktury f
join PozycjeFaktur p on f.FaktId = p.FaktId
where NumerFa = '<NEW-TABTYPE>'

/*
-- problemy
1. READONLY w definicji parametrów - nie da siê zmieniaæ zawartoœci w procedurze
2. PROBLEM Z ELASTYCZNOŒCI¥, gdy dochodzi nowa kolumna np.: DROP TYPE tFaktury
*/
drop type tFaktury;
