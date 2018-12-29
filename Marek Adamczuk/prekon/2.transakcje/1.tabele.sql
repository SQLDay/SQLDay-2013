USE master
GO
IF DB_ID('Magazyn') IS NOT NULL BEGIN
  ALTER DATABASE Magazyn SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
  DROP DATABASE Magazyn;
END;
GO
CREATE DATABASE Magazyn;
GO
USE Magazyn;
GO
CREATE TABLE dbo.Towary (
  TowarId varchar(2) NOT NULL,
  Stan int NOT NULL CONSTRAINT DF_Towary_Stan DEFAULT 0,
  CONSTRAINT CK_Towary_Stan CHECK (Stan >= 0), -- kontrola stanu magazynu. nie mo¿e byæ ujemny!
  CONSTRAINT PK_Towary PRIMARY KEY (TowarId)
  );
GO
CREATE TABLE dbo.NaglowkiDow (
  DowId int IDENTITY (1,1),
  Data  date NOT NULL CONSTRAINT DF_NaglowkiDow_Data DEFAULT GETDATE(),
  Rodzaj varchar(2) NOT NULL,
  NumerDow int NULL,
  IloscRazem int NULL,
  CONSTRAINT CK_NaglowkiDow_Rodzaj CHECK (Rodzaj IN ('P','R')), -- przychód lub rozchód
  CONSTRAINT PK_NaglowkiDow PRIMARY KEY (DowId)
  );
GO
CREATE TABLE dbo.PozycjeDow (
  DowId int NOT NULL,
  TowarId varchar(2) NOT NULL,
  Ilosc int NOT NULL,
  CONSTRAINT PK_PozycjeDow PRIMARY KEY (DowId, TowarId), -- tylko jedno wyst¹pienie towaru na dowód!
  CONSTRAINT FK_PozycjeDow_Towary FOREIGN KEY (TowarId) REFERENCES dbo.Towary (TowarId),
  CONSTRAINT FK_PozycjeDow_NaglowkiDow FOREIGN KEY (DowId) REFERENCES dbo.NaglowkiDow (DowId)
  );
GO
CREATE TABLE dbo.Zamowienia (
  ZamId int,
  DowId int NULL,
  CONSTRAINT PK_Zamowienia PRIMARY KEY (ZamId)
  );
GO
IF TYPE_ID('TPozycjeDow') IS NULL
  CREATE TYPE TPozycjeDow AS TABLE (TowarId varchar(2), Ilosc int)
GO
