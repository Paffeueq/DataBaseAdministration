/* 2025.12.09 maciej.stodolski@gmail.com 
Usuwanie kolumny na której są ogranicznie

TREŚć zadania na końcu

*/

/*
Nie zawsze jest możliwe usunięcie kolumny - zwłaszcza jeżeli kolumna ta ma wiele ograniczeń */
use B25_ADM_PM331720
go

/* mamy poniższe dwie tabele */

if object_id('DETAIL_TB') is not null
	drop table DETAIL_TB
GO

if object_id('MASTER_TB') is not null
	drop table MASTER_TB
GO

CREATE TABLE dbo.MASTER_TB
(	master_id nvarchar(20) not null constraint PK_MASTER_TB PRIMARY KEY
)
insert into MASTER_TB (MASTER_ID) VALUES (N'M01')
GO

/* w poniższej tabeli kolumna MASTER_ID ma 2 ograniczenia: 1. JEST KLUCZEM OBCYM 2 MA DEFAULT */

CREATE TABLE dbo.DETAIL_TB
(	master_id nvarchar(20) not null DEFAULT N'M01'
		constraint FK_DETAIL__MASTER_TB FOREIGN KEY REFERENCES MASTER_TB(MASTER_ID)
,	DETAIL_ID NVARCHAR(20) NOT NULL  CONSTRAINT PK_DETAIL_TB PRIMARY KEY
)

INSERT INTO DETAIL_TB (MASTER_ID, DETAIL_ID)
	VALUES (N'M01', N'D01')
GO

SELECT * FROM DETAIL_TB
/*
master_id            DETAIL_ID
-------------------- --------------------
M01                  D01

(1 row(s) affected)
*/

/* chcemy skasować w tabeli DETAIL_TB kolumnę MASTER_ID
*/

ALTER TABLE DETAIL_TB DROP COLUMN MASTER_ID

/* 
** jest to niemożliwe bo sa CONSTRAINTS związane z tą kolumną:
Msg 5074, Level 16, State 1, Line 1
The object 'DF__DETAIL_TB__maste__3E52440B' is dependent on column 'MASTER_ID'.
Msg 5074, Level 16, State 1, Line 1
The object 'FK_DETAIL__MASTER_TB' is dependent on column 'MASTER_ID'.
Msg 4922, Level 16, State 9, Line 1
ALTER TABLE DROP COLUMN MASTER_ID failed because one or more objects access this column.

*/
/* najpierw musimy usunąć CONSTRAINTS a dopiero potem możemy kolumnę
** UWAGA !!! Ograniczenie związane z DEFAULT u każdego z Państwa będzie mieć inna nazwę niż u mnie
*/
use B25_ADM_PM331720;ALTER TABLE DETAIL_TB DROP CONSTRAINT DF__DETAIL_TB__maste__3E52440B
/*Command(s) completed successfully.
*/
DECLARE  @sql nvarchar(1000)
SET @sql = N'use B25_ADM_PM331720;ALTER TABLE DETAIL_TB DROP CONSTRAINT FK_DETAIL__MASTER_TB'
EXEC sp_sqlExec @sql 
GO
/*Command(s) completed successfully.
*/

/* Po usunięciu ograniczeń można usunąć kolumnę */

ALTER TABLE DETAIL_TB DROP COLUMN MASTER_ID
/*Command(s) completed successfully.
*/


SELECT * FROM DETAIL_TB
/*
DETAIL_ID
--------------------
D01

(1 row(s) affected)
*/

/*
** ZADANIE: Napisać procedurę usun_kol, która 
** Będzie mieć parametry: nazwa_bazy, nazwa_tabeli, nazwa_kolumn
** w pętli/kursorze wykasuje WSZYSTKIE ograniczenia (CONSTRAINTS)
** związane z tą kolumną
** na koncu wykasuje tę kolumnę
** dowód działania taki jak ja zrobiłem
*/

-- ROZWIĄZANIE:
USE B25_ADM_PM331720
GO

IF OBJECT_ID('usun_kol') IS NOT NULL
	DROP PROCEDURE usun_kol
GO

CREATE PROCEDURE usun_kol
	@nazwa_bazy NVARCHAR(128),
	@nazwa_tabeli NVARCHAR(128),
	@nazwa_kolumny NVARCHAR(128)
AS
BEGIN
	DECLARE @sql NVARCHAR(MAX)
	DECLARE @constraint_name NVARCHAR(128)
	
	-- Sprawdzenie czy kolumna istnieje
	IF NOT EXISTS (
		SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
		WHERE TABLE_CATALOG = @nazwa_bazy
		AND TABLE_NAME = @nazwa_tabeli
		AND COLUMN_NAME = @nazwa_kolumny
	)
	BEGIN
		RAISERROR('Kolumna %s nie istnieje w tabeli %s.%s', 16, 1, @nazwa_kolumny, @nazwa_bazy, @nazwa_tabeli)
		RETURN
	END
	
	-- Kursor do usunięcia wszystkich constraints związanych z kolumną
	DECLARE constraint_cursor CURSOR FOR
		SELECT CONSTRAINT_NAME
		FROM INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE
		WHERE TABLE_CATALOG = @nazwa_bazy
		AND TABLE_NAME = @nazwa_tabeli
		AND COLUMN_NAME = @nazwa_kolumny
		UNION
		SELECT d.name
		FROM sys.default_constraints d
		JOIN sys.columns c ON d.parent_object_id = OBJECT_ID(@nazwa_tabeli)
		AND d.parent_column_id = c.column_id
		WHERE c.name = @nazwa_kolumny
	
	OPEN constraint_cursor
	FETCH NEXT FROM constraint_cursor INTO @constraint_name
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @sql = N'ALTER TABLE [' + @nazwa_bazy + '].dbo.[' + @nazwa_tabeli + '] DROP CONSTRAINT [' + @constraint_name + ']'
		EXEC sp_executesql @sql
		PRINT 'Usunięto constraint: ' + @constraint_name
		
		FETCH NEXT FROM constraint_cursor INTO @constraint_name
	END
	
	CLOSE constraint_cursor
	DEALLOCATE constraint_cursor
	
	-- Usunięcie kolumny
	SET @sql = N'ALTER TABLE [' + @nazwa_bazy + '].dbo.[' + @nazwa_tabeli + '] DROP COLUMN [' + @nazwa_kolumny + ']'
	EXEC sp_executesql @sql
	PRINT 'Usunięto kolumnę: ' + @nazwa_kolumny
	
END
GO

-- DOWÓD DZIAŁANIA:
-- Przywrócenie struktury do testów
IF OBJECT_ID('DETAIL_TB') IS NOT NULL
	DROP TABLE DETAIL_TB
GO

IF OBJECT_ID('MASTER_TB') IS NOT NULL
	DROP TABLE MASTER_TB
GO

CREATE TABLE dbo.MASTER_TB
(	master_id nvarchar(20) not null constraint PK_MASTER_TB PRIMARY KEY
)
INSERT INTO MASTER_TB (MASTER_ID) VALUES (N'M01')
GO

CREATE TABLE dbo.DETAIL_TB
(	master_id nvarchar(20) not null DEFAULT N'M01'
		constraint FK_DETAIL__MASTER_TB FOREIGN KEY REFERENCES MASTER_TB(MASTER_ID)
,	DETAIL_ID NVARCHAR(20) NOT NULL CONSTRAINT PK_DETAIL_TB PRIMARY KEY
)

INSERT INTO DETAIL_TB (MASTER_ID, DETAIL_ID)
	VALUES (N'M01', N'D01')
GO

PRINT '=== PRZED usunięciem kolumny ==='
SELECT * FROM DETAIL_TB
GO

-- Wywołanie procedury
EXEC usun_kol @nazwa_bazy = 'B25_ADM_PM331720', @nazwa_tabeli = 'DETAIL_TB', @nazwa_kolumny = 'MASTER_ID'
GO

PRINT '=== PO usunięciu kolumny ==='
SELECT * FROM DETAIL_TB
GO
*/
  