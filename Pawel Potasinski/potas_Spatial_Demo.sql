/*

SQLDay 2013
Geografia w SQL Server 2012
Pawel Potasinski

*/

--------------------------------------
-- O typie geography
--------------------------------------

SELECT name, system_type_id, user_type_id, is_assembly_type 
FROM sys.types 
WHERE name = 'geography';
GO

SELECT t.name as type_name, a.name as assembly_name
FROM sys.assembly_types AS t
INNER JOIN sys.assemblies AS a
ON t.assembly_id = a.assembly_id;
GO

SELECT * 
FROM sys.spatial_reference_systems;
GO

--

USE Poland;
GO

DECLARE @SQLDay geography = 
	geography::STGeomFromText('POINT(16.943726 51.141164)', 4326);
SELECT geom, 'Polska', geom.ToString() AS def
FROM dbo.POL_adm0 
UNION ALL
SELECT @SQLDay.STBuffer(10000), 'SQLDay 2013', @SQLDay.ToString();
GO

--------------------------------------------
-- Indeksy przestrzenne - metadane
--------------------------------------------

SELECT * FROM sys.spatial_indexes;
GO

SELECT * FROM sys.spatial_index_tessellations;
GO

--------------------------------------------
-- Indeksy przestrzenne - internals
--------------------------------------------

SELECT name, OBJECT_NAME(parent_object_id) AS parent_object
FROM Poland.sys.internal_tables
WHERE internal_type_desc = 'EXTENDED_INDEXES';
GO

--Cell_Attributes:
--0 – komorka przynajmniej dotyka obiektu (ale nie 1 lub 2)
--1 – obiekt na pewno czesciowo pokrywa komorke
--2 – obiekt pokrywa komorke 
:CONNECT Admin:localhost
SELECT *
FROM Poland.sys.extended_index_485576768_384000
GO

USE Poland;
GO
SELECT i.name AS index_name, i.type_desc, c.name AS column_name
FROM sys.indexes AS i
INNER JOIN sys.index_columns AS ic
ON i.object_id = ic.object_id AND i.index_id = ic.index_id
INNER JOIN sys.columns AS c
ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE i.object_id = OBJECT_ID('sys.extended_index_485576768_384000');
GO

--SELECT *
--FROM Poland.sys.extended_index_485576768_384001;
--GO

--------------------------------------------
-- Indeksy przestrzenne - wykorzystanie
--------------------------------------------

USE Poland;
GO

SET STATISTICS TIME ON;
GO

DECLARE @SQLDay geography = geography::STGeomFromText('POINT(16.943726 51.141164)', 4326);
SELECT geom, name
FROM dbo.roads WITH (INDEX(0))
WHERE @SQLDay.STDistance(geom) < 3000
UNION ALL
SELECT @SQLDay.STBuffer(100), 'SQLDay';
GO

-- Typowy indeks przestrzenny z SQL Server 2008 R2
--CREATE SPATIAL INDEX SIDX_roads_MMMM on dbo.roads(geom)
--WITH (GRIDS=(MEDIUM,MEDIUM,MEDIUM,MEDIUM));

-- Indeks przestrzenny z domyslnym podzialem siatki
--CREATE SPATIAL INDEX SIDX_roads_AUTO on dbo.roads(geom);

DECLARE @SQLDay geography = 
	geography::STGeomFromText('POINT(16.943726 51.141164)', 4326);

-- Zapytanie ze starym indeksem
SELECT geom, name
FROM dbo.roads WITH (INDEX(SIDX_roads_MMMM))
WHERE @SQLDay.STDistance(geom) < 3000
UNION ALL
SELECT @SQLDay.STBuffer(100), 'SQLDay';

-- Zapytanie z nowym indeksem
SELECT geom, name
FROM dbo.roads WITH (INDEX(SIDX_roads_AUTO))
WHERE @SQLDay.STDistance(geom) < 3000
UNION ALL
SELECT @SQLDay.STBuffer(100), 'SQLDay';

GO

-- Dlaczego?
DECLARE @SQLDay geography = 
	geography::STGeomFromText('POINT(16.943726 51.141164)', 4326);

SELECT COUNT(*)
FROM dbo.roads WITH (INDEX(SIDX_roads_AUTO))
WHERE geom.Filter(@SQLDay.STBuffer(3000)) = 1;

SELECT COUNT(*)
FROM dbo.roads WITH (INDEX(SIDX_roads_AUTO))
WHERE geom.STIntersects(@SQLDay.STBuffer(3000)) = 1;

SELECT COUNT(*)
FROM dbo.roads WITH (INDEX(SIDX_roads_MMMM))
WHERE geom.Filter(@SQLDay.STBuffer(3000)) = 1;

GO

-- Przemiennoœæ (?)
DECLARE @SQLDay geography = 
	geography::STGeomFromText('POINT(16.943726 51.141164)', 4326);

SELECT geom, name
FROM dbo.roads WITH (INDEX(SIDX_roads_AUTO))
WHERE @SQLDay.STDistance(geom) < 3000;

SELECT geom, name
FROM dbo.roads WITH (INDEX(SIDX_roads_AUTO))
WHERE geom.STDistance(@SQLDay) < 3000;

SELECT geom, name
FROM dbo.roads WITH (INDEX(SIDX_roads_AUTO))
WHERE @SQLDay.STBuffer(3000).STIntersects(geom) = 1;

--Bug...
SELECT geom, name
FROM dbo.roads WITH (INDEX(SIDX_roads_AUTO))
WHERE 1 = @SQLDay.STBuffer(3000).STIntersects(geom);

GO

--CREATE SPATIAL INDEX SIDX_points_AUTO on dbo.points(geom);

-- Wsparcie dla zapytan o najblizszych sasiadow
DECLARE @SQLDay geography = 
	geography::STGeomFromText('POINT(16.943726 51.141164)', 4326);

SELECT TOP(5) *, geom.STDistance(@SQLDay) AS distance
FROM dbo.points
WHERE type = 'restaurant'
AND geom.STDistance(@SQLDay) IS NOT NULL
ORDER BY geom.STDistance(@SQLDay);

---------------------
-- Tips & Tricks
---------------------

-- Procedury
EXEC sys.sp_help_spatial_geography_histogram 'roads', 'geom', 16;
GO

-- Jak z obszaru zrobiæ punkt? (Power View, GeoFlow)
SELECT VARNAME_1, geom 
FROM dbo.POL_adm1
UNION ALL
SELECT 
	VARNAME_1, 
	geography::STGeomFromText('POINT(' + 
		CONVERT(varchar(100), geom.EnvelopeCenter().Long) +
		' ' + CONVERT(varchar(100), geom.EnvelopeCenter().Lat) + 
		')', 4326).STBuffer(10000)
FROM dbo.POL_adm1;
GO

-- Jak do map do³¹czyæ informacjê analityczn¹?
--...
--DROP TABLE #SalesByTerritory;
SELECT 
	[[Salesman]].[Territory Name]].[Territory Name]].[MEMBER_CAPTION]]] AS Territory,
	[[Measures]].[Sales Amount]]] AS SalesAmount
INTO #SalesByTerritory
FROM OPENQUERY(
	AW_OLAP, 
	'SELECT
	  [Measures].[Sales Amount] ON COLUMNS,
	  [Salesman].[Territory Name].Members ON ROWS
	FROM [AdventureWorks]'
) AS Q;
SELECT * FROM #SalesByTerritory;
--...
GO