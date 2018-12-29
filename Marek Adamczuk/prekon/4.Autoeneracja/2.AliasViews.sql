USE SQLDay2013;
GO

IF OBJECT_ID('dbo.Adresy') IS NOT NULL DROP TABLE adresy
GO
CREATE TABLE dbo.Adresy (
  KlientId int,
  Przeznaczenie varchar(10) DEFAULT 'FAKTURA',
  Nazwa varchar(100),
  KodPocztowy varchar(10),
  Miejscowosc varchar(100),
  Ulica varchar(100),
  CONSTRAINT PK_Adresy PRIMARY KEY (KlientId, Przeznaczenie),
  CONSTRAINT CK_Adresy CHECK (Przeznaczenie IN ('FAKTURA','ODBIOR')),
  CONSTRAINT FK_Adresy_klienci FOREIGN KEY (KlientId) REFERENCES Klienci (KlientId)
  )
GO
SELECT * 
  FROM dbo.Klienci k
  LEFT JOIN dbo.Adresy faktura on k.KlientId = faktura.KlientId AND faktura.Przeznaczenie = 'FAKTURA'
  LEFT JOIN dbo.Adresy odbior on k.KlientId = odbior.KlientId and odbior.Przeznaczenie = 'ODBIOR'
GO
CREATE VIEW dbo.vKlienciZAdresami
AS
SELECT * 
  FROM dbo.Klienci k
  LEFT JOIN dbo.Adresy faktura on k.KlientId = faktura.KlientId AND faktura.Przeznaczenie = 'FAKTURA'
  LEFT JOIN dbo.Adresy odbior on k.KlientId = odbior.KlientId and odbior.Przeznaczenie = 'ODBIOR'
GO
select 'k.'+c.name+','
    from sys.columns c where object_id = object_id('Klienci')

  select 'f.'+c.name+' as f_'+name+','
    from sys.columns c where object_id = object_id('Adresy')

  select 'o.'+c.name+' as o_'+name+','
    from sys.columns c where object_id = object_id('Adresy')

GO
CREATE VIEW dbo.vKlienciZAdresami
AS
SELECT 
k.KlientId,
k.NazwaKlienta,
k.NIP,
--k.KodPocztowy,
--k.Miejscowosc,
--k.Ulica,
--k.NumerDomu,
k.Rachunek,
--f.KlientId as f_KlientId,
--f.Przeznaczenie as f_Przeznaczenie,
f.Nazwa as f_Nazwa,
f.KodPocztowy as f_KodPocztowy,
f.Miejscowosc as f_Miejscowosc,
f.Ulica as f_Ulica,
--o.KlientId as o_KlientId,
--o.Przeznaczenie as o_Przeznaczenie,
o.Nazwa as o_Nazwa,
o.KodPocztowy as o_KodPocztowy,
o.Miejscowosc as o_Miejscowosc,
o.Ulica as o_Ulica
FROM dbo.Klienci k
  LEFT JOIN dbo.Adresy f on k.KlientId = f.KlientId AND f.Przeznaczenie = 'FAKTURA'
  LEFT JOIN dbo.Adresy o on k.KlientId = o.KlientId and o.Przeznaczenie = 'ODBIOR'
GO  
-- a teraz
ALTER TABLE dbo.Adresy ADD NrDomu varchar(20);
GO
-- przerabiaæ widok? A jak jest ich du¿o??
GO

    
 




CREATE TABLE dbo.AliasViews (
  ViewName sysname,
  BaseTable sysname,
  DefaultPrefix varchar(100),
  WhereClause varchar(1000),
  PRIMARY KEY (ViewName)
  )
GO
CREATE TABLE dbo.AliasViewSpecialCols (
  ViewName sysname,
  ColName sysname,
  AliasColName sysname NULL,
  Exclude bit DEFAULT 0,
  PRIMARY KEY (ViewName, ColName)
  )
GO

  
GO
IF OBJECT_ID('dbo.getAliasView') IS NOT NULL DROP FUNCTION dbo.getAliasView;
GO
CREATE FUNCTION dbo.getAliasView(@ViewName sysname)
RETURNS @t TABLE (line nvarchar(max), id int identity primary key)
AS
BEGIN
  DECLARE @BaseTable sysname, @DefaultPrefix varchar(100), @WhereClause varchar(1000);
  SELECT 
  @ViewName = a.ViewName, 
  @BaseTable = a.BaseTable, 
  @DefaultPrefix = a.DefaultPrefix,
  @WhereClause = a.WhereClause
  FROM dbo.AliasViews a WHERE a.ViewName = @ViewName;
  INSERT INTO @t (line) SELECT 'CREATE VIEW dbo.'+QUOTENAME(@ViewName);
  INSERT INTO @t (line) SELECT 'AS  -- obiekt autogenerowany, grzebanie grozi œmierci¹ lub kalectwem';
  INSERT INTO @t (line) SELECT 'SELECT';
  INSERT INTO @t (line) SELECT 
  iif(ac.Exclude = 1,'--','')+
  quotename(c.name)+' AS '+QUOTENAME(ISNULL(ac.AliasColName,@DefaultPrefix+c.name))+','  
  FROM sys.columns c
  LEFT JOIN dbo.AliasViewSpecialCols ac ON ac.ViewName = @ViewName and ac.ColName = c.name 
  WHERE c.object_id = object_id(@BaseTable)
  ORDER BY c.column_id

  IF @@rowcount > 0 UPDATE @t set line = substring(line,1,len(line)-1) where id = @@identity; -- wywalamy ostatni przecinek
  INSERT INTO @t (line) SELECT 'FROM dbo.'+@BaseTable
  IF @WhereClause is not null
  INSERT INTO @t (line) SELECT @WhereClause;
  RETURN;
END;
GO


if object_id('dbo.rebuildAliasView') is not null drop procedure dbo.rebuildAliasView;
GO
create procedure dbo.rebuildAliasView @ViewName sysname
as
begin
  DECLARE @TranCnt int = @@TRANCOUNT;
  DECLARE @SavePoint varchar(40) SET @SavePoint = REPLACE(CONVERT(VARCHAR(36),NEWID()),'-','');
  IF @TranCnt = 0 BEGIN TRAN; 
  SAVE TRAN @SavePoint;
  
  DECLARE @SQL nvarchar(max);
 
  SELECT @SQL = 'IF OBJECT_ID('+quotename(@ViewName,'''')+') IS NOT NULL DROP VIEW dbo.'+quotename(@ViewName)+';';
  IF @@ERROR <> 0 GOTO END_ROLLBACK;  

  EXEC (@SQL);
  IF @@ERROR <> 0 GOTO END_ROLLBACK;  
  
  SET @SQL = N'';
  SELECT TOP 99999999999999 @SQL = @SQL+l.line+char(13)+char(10)
  FROM dbo.getAliasView(@ViewName) l 
  ORDER BY l.id;
  IF @@ERROR <> 0 GOTO END_ROLLBACK;  

  EXEC (@SQL);
  IF @@ERROR <> 0 GOTO END_ROLLBACK;  

  IF @TranCnt = 0 AND @@TRANCOUNT > 0 COMMIT TRAN;
  RETURN 0;
  END_ROLLBACK:
  IF @@TRANCOUNT > 0 ROLLBACK TRAN @SavePoint;
  IF @TranCnt = 0 AND @@TRANCOUNT > 0 ROLLBACK TRAN;
  RETURN -1; 
end;
GO
GO
if object_id('dbo.rebuildAllAliasViews') is not null drop procedure dbo.rebuildAllAliasViews;
GO
create procedure dbo.rebuildAllAliasViews
as
begin
  DECLARE @TranCnt int = @@TRANCOUNT;
  DECLARE @SavePoint varchar(40) SET @SavePoint = REPLACE(CONVERT(VARCHAR(36),NEWID()),'-','');
  IF @TranCnt = 0 BEGIN TRAN; 
  SAVE TRAN @SavePoint;
  
  DECLARE @ViewName sysname, @Result int = 0;
  DECLARE c CURSOR LOCAL FAST_FORWARD FOR 
  SELECT a.ViewName FROM dbo.AliasViews a;

  OPEN c;
  FETCH NEXT FROM c into @ViewName;
  WHILE @@fetch_status = 0 BEGIN
    EXEC @Result = dbo.rebuildAliasView @ViewName;
    FETCH NEXT FROM c into @ViewName;
  END;
  CLOSE c; DEALLOCATE c;

  IF @TranCnt = 0 AND @@TRANCOUNT > 0 COMMIT TRAN;
  RETURN 0;
  END_ROLLBACK:
  IF @@TRANCOUNT > 0 ROLLBACK TRAN @SavePoint;
  IF @TranCnt = 0 AND @@TRANCOUNT > 0 ROLLBACK TRAN;
  RETURN -1; 
end;
GO

GO
INSERT AliasViews (ViewName, BaseTable, DefaultPrefix, WhereClause)
SELECT 'vAdresDoFaktury','Adresy','f_','where Przeznaczenie = ''FAKTURA'''
INSERT AliasViews (ViewName, BaseTable, DefaultPrefix, WhereClause)
SELECT 'vAdresOdbioru','Adresy','o_','where Przeznaczenie = ''ODBIOR'''

EXEC rebuildAllAliasViews
GO
sp_helptext vAdresDoFaktury
GO
-- wyrzucamy pole "Przeznaczenie"
INSERT AliasViewSpecialCols (ViewName, ColName, AliasColName, Exclude)
SELECT 'vAdresDoFaktury','Przeznaczenie',NULL,1

INSERT AliasViewSpecialCols (ViewName, ColName, AliasColName, Exclude)
SELECT 'vAdresOdbioru','Przeznaczenie',NULL,1
GO
EXEC rebuildAllAliasViews
GO
sp_helptext vAdresDoFaktury
GO
CREATE VIEW dbo.vKlienciZAdresamiAuto1
AS
SELECT * 
FROM dbo.Klienci k
LEFT JOIN dbo.vAdresDoFaktury f on f.f_klientId = k.KlientId
LEFT JOIN dbo.vAdresOdbioru o on o.o_klientId = k.KlientId
GO
select * from dbo.vKlienciZAdresamiAuto1

INSERT AliasViews (ViewName, BaseTable, DefaultPrefix, WhereClause)
SELECT 'vOstateczniKlienci','vKlienciZAdresamiAuto1','',NULL
GO
EXEC rebuildAllAliasViews
GO
sp_helptext vOstateczniKlienci
GO

INSERT AliasViewSpecialCols (ViewName, ColName, AliasColName, Exclude)
SELECT 'vOstateczniKlienci','KodPocztowy',NULL,1
INSERT AliasViewSpecialCols (ViewName, ColName, AliasColName, Exclude)
SELECT 'vOstateczniKlienci','Miejscowosc',NULL,1
INSERT AliasViewSpecialCols (ViewName, ColName, AliasColName, Exclude)
SELECT 'vOstateczniKlienci','Ulica',NULL,1
INSERT AliasViewSpecialCols (ViewName, ColName, AliasColName, Exclude)
SELECT 'vOstateczniKlienci','NrDomu',NULL,1
INSERT AliasViewSpecialCols (ViewName, ColName, AliasColName, Exclude)
SELECT 'vOstateczniKlienci','f_KlientId',NULL,1
INSERT AliasViewSpecialCols (ViewName, ColName, AliasColName, Exclude)
SELECT 'vOstateczniKlienci','o_KlientId',NULL,1
GO
EXEC rebuildAllAliasViews
GO
sp_helptext vOstateczniKlienci
GO
alter table Adresy ADD NrLokalu varchar(100), Poczta varchar(200);


EXEC rebuildAllAliasViews;-- naprawiamy widoki vAdresDoFaktury i vAdresOdbioru
EXEC sp_refreshview 'vKlienciZAdresamiAuto1'
EXEC rebuildAllAliasViews;-- jeszcze raz naprawa wszystkiego
GO
sp_helptext vOstateczniKlienci



