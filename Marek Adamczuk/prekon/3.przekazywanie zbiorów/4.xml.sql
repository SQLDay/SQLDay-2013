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
if object_id('dbo.FakturyXMLtoTab') is not null drop function dbo.FakturyXMLtoTab;
GO
create function dbo.FakturyXMLtoTab(@d xml)
returns table
as return (
select 
   t.c.value('FaktId[1]','int') as FaktId,
   t.c.value('KlientId[1]','int') as KlientId,
   t.c.value('Data[1]','datetime') as Data,
   t.c.value('Uwagi[1]','varchar(800)') as Uwagi,
   t.c.value('NumerFa[1]','varchar(20)') as NumerFa
from @d.nodes('//row') as t(c)
);
GO
declare @X_faktury xml;
select @X_faktury = (SELECT TOP 10 * FROM dbo.Faktury FOR XML PATH, TYPE)
SELECT @X_faktury;
select * from dbo.FakturyXMLtoTab(@X_faktury)
GO
if object_id('dbo.PozycjeFakturXMLtoTab') is not null drop function dbo.PozycjeFakturXMLtoTab;
GO
create function dbo.PozycjeFakturXMLtoTab(@d xml)
returns table 
as return (
select
   t.c.value('FaktId[1]','int') as FaktId,
   t.c.value('NrPoz[1]','int') as NrPoz,
   t.c.value('TowarId[1]','int') as TowarId,
   t.c.value('Ilosc[1]','int') as Ilosc,
   t.c.value('Cena[1]','money') as Cena
from @d.nodes('//row') as t(c)
);
GO
IF OBJECT_ID('dbo.modyfikuj_faktury_XML') IS NOT NULL DROP PROCEDURE dbo.modyfikuj_faktury_XML;
GO
CREATE PROCEDURE dbo.modyfikuj_faktury_XML 
    @XFaktury xml OUTPUT, 
    @XPozycjeFaktur xml OUTPUT -- UWAGA! To wszystko da³oby siê zmieœciæ w pojedynczym parametrze XML
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @TranCnt int = @@TRANCOUNT;
  DECLARE @SavePoint varchar(40) SET @SavePoint = REPLACE(CONVERT(VARCHAR(36),NEWID()),'-','');
  IF @TranCnt = 0 BEGIN TRAN; 
  SAVE TRAN @SavePoint;
  
  DECLARE @nowe_faktury TABLE (FaktId int, tmpFaktId int);
  
  DECLARE @tmp_Faktury table (
   FaktId	int,
   KlientId	int,
   Data	 datetime,
   Uwagi varchar(800),
   NumerFa varchar(20)
   );
  
  DECLARE @tmp_PozycjeFaktur TABLE(
  FaktId	int,
  NrPoz	int,
  TowarId	int,
  Ilosc	int,
  Cena	money);

  -- uciekamy od skomplikowania XML-a
  INSERT INTO @tmp_Faktury (FaktId, KlientId, Data, Uwagi, NumerFa) 
  SELECT x.FaktId, x.KlientId, x.Data, x.Uwagi, x.NumerFa FROM dbo.FakturyXMLtoTab(@XFaktury) x;
  
  INSERT INTO @tmp_PozycjeFaktur (FaktId, NrPoz, TowarId, Ilosc, Cena)
  SELECT x.FaktId, x.NrPoz, x.TowarId, x.Ilosc, x.Cena FROM dbo.PozycjeFakturXMLtoTab(@XPozycjeFaktur) x;

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
  n.FaktId, t.KlientId, t.Data, t.Uwagi, t.NumerFa From @tmp_Faktury t  
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

  -- Nadpisz interfejsy nowymi id-kami faktur
  UPDATE t
    SET t.FaktId = n.FaktId
  FROM @tmp_Faktury t 
  JOIN @nowe_faktury n on t.FaktId = n.tmpFaktId;
  IF @@ERROR <> 0 GOTO END_ROLLBACK;

  UPDATE t
  SET t.FaktId = n.FaktId
  FROM @tmp_PozycjeFaktur t 
  JOIN @nowe_faktury n on t.FaktId = n.tmpFaktId;
  IF @@ERROR <> 0 GOTO END_ROLLBACK;

  -- Pozycje: trochê brutalnie. Wyrzuæ i wrzuæ wszystko. Mo¿na to zrobiæ bardziej elegancko
  DELETE FROM p
  FROM dbo.PozycjeFaktur p
  WHERE FaktId in (SELECT f.FaktId FROM @tmp_Faktury f WHERE f.FaktId = p.FaktId);
  IF @@ERROR <> 0 GOTO END_ROLLBACK;

  INSERT INTO dbo.PozycjeFaktur (FaktId, NrPoz, TowarId, Ilosc, Cena)
  SELECT t.FaktId, t.NrPoz, t.TowarId, t.Ilosc, t.Cena
  FROM @tmp_PozycjeFaktur t;
  IF @@ERROR <> 0 GOTO END_ROLLBACK;
  
  -- nadpisujemy ponownie parametry zmienionymi wartoœciami
  SELECT @XFaktury = 
  (SELECT f.* FROM dbo.Faktury f 
   WHERE f.FaktId IN (SELECT t.FaktId FROM @tmp_Faktury t) FOR XML PATH, TYPE);
  
  SELECT @XPozycjeFaktur = 
  (SELECT f.* FROM dbo.PozycjeFaktur f 
   WHERE f.FaktId IN (SELECT t.FaktId FROM @tmp_Faktury t) FOR XML PATH, TYPE);

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
declare @f xml = (
select top 10 -KlientId as FaktId, 
k.KlientId, 
convert(date, getdate()) Data,
'Faktura klienta '+k.NazwaKlienta Uwagi,
'<NEW-XML>' NumerFa
from dbo.klienci k order by newid()
for xml path, type);
declare @p xml = (
SELECT t.FaktId, 
  row_number() over(partition by t.FaktId order by tow.TowarId) NrPoz,
  tow.TowarId,
  abs(checksum(newid()))%10+1 Ilosc, -- do 10
  (abs(checksum(newid()))%10000+1)/$100 Cena -- do 100
FROM dbo.FakturyXMLtoTab(@f) as t
CROSS APPLY (SELECT TOP 10 tow.TowarId FROM Towary tow ORDER BY NewId()) tow
FOR xml path, type)
exec dbo.modyfikuj_faktury_xml @f output, @p output;
select * FROM dbo.FakturyXMLtoTab(@f);
select * FROM dbo.PozycjeFakturXMLtoTab(@p);
GO
/*
PROBLEMY:
1. Trzeba siê gimnastykowaæ z typem XML
2. Update'y bezpoœrednio na zmiennych XML uci¹¿liwe - lepiej przejœæ na @tabelê


KORZYŒCI
1. Znakomita elastycznoœæ - XML mo¿e zawieraæ zarówno wiêcej, jak i mniej elementów 
ni¿ jest obs³u¿onych w procedurze kolumn (jeœli nie wymagane)
2. Daje siê modyfikowaæ parametry wewn¹trz procedury
3. Parametry przekazane jawnie - nie trzeba kontrolowaæ sesji
4. Operacje na zbiorach roboczych nie podlegaj¹ lockowaniu
*/