/* ================== Z2 – wersja prosta, SQL Server 2012 ================== */
SET NOCOUNT ON;

/* 0) B25_ADM – utwórz, jeśli brak */
IF DB_ID(N'B25_ADM') IS NULL
BEGIN
  EXEC('CREATE DATABASE [B25_ADM]');
END
GO

USE [B25_ADM];
GO

/* 1) Tabele administracyjne (idempotentnie) */
IF OBJECT_ID('dbo.DB_CHECK','U') IS NULL
CREATE TABLE dbo.DB_CHECK
( check_id int IDENTITY(1,1) PRIMARY KEY,
  db_nam   nvarchar(50) NOT NULL,
  d_stamp  datetime NOT NULL DEFAULT GETDATE(),
  opis     nvarchar(50) NOT NULL,
  [usr]    nvarchar(50) NOT NULL DEFAULT USER_NAME(),
  [s_usr]  nvarchar(50) NOT NULL DEFAULT SUSER_NAME()
);

IF OBJECT_ID('dbo.DB_CHECK_ITEMS','U') IS NOT NULL
    PRINT 'DB_CHECK_ITEMS już istnieje';
ELSE
CREATE TABLE dbo.DB_CHECK_ITEMS
( check_id int NOT NULL FOREIGN KEY REFERENCES dbo.DB_CHECK(check_id),
  tb_nam   nvarchar(256) NOT NULL,
  liczba_reordow int NOT NULL,
  tb_check_d_stamp datetime NOT NULL DEFAULT GETDATE()
);

/* 2) Sprzątanie starych procedur (gdyby były) */
IF OBJECT_ID('dbo.pr_seed_baz_bazowe_tabele','P') IS NOT NULL DROP PROCEDURE dbo.pr_seed_baz_bazowe_tabele;
IF OBJECT_ID('dbo.pr_run_db_check_v2012','P') IS NOT NULL DROP PROCEDURE dbo.pr_run_db_check_v2012;
IF OBJECT_ID('dbo.pr_run_db_check','P') IS NOT NULL DROP PROCEDURE dbo.pr_run_db_check;
GO

/* 3) Utwórz 5 baz: B25_DB1..B25_DB5 */
DECLARE @i int = 1, @db sysname;
WHILE @i <= 5
BEGIN
  SET @db = N'B25_DB' + CAST(@i AS nvarchar(10));
  IF DB_ID(@db) IS NULL
    EXEC('CREATE DATABASE [' + @db + ']');
  SET @i = @i + 1;
END
GO

/* 4) Procedura seeda – osobny batch (CREATE musi być 1. w batchu) */
CREATE PROCEDURE dbo.pr_seed_baz_bazowe_tabele
  @db sysname
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @sql nvarchar(max);
  SET @sql = N'
USE ' + QUOTENAME(@db) + N';
SET NOCOUNT ON;

IF OBJECT_ID(''dbo.ETATY'',''U'') IS NOT NULL DROP TABLE dbo.ETATY;
IF OBJECT_ID(''dbo.OSOBY'',''U'') IS NOT NULL DROP TABLE dbo.OSOBY;
IF OBJECT_ID(''dbo.MIASTA'',''U'') IS NOT NULL DROP TABLE dbo.MIASTA;
IF OBJECT_ID(''dbo.WOJ'',''U'')   IS NOT NULL DROP TABLE dbo.WOJ;

CREATE TABLE dbo.WOJ
( kod_woj char(3) NOT NULL CONSTRAINT PK_WOJ PRIMARY KEY,
  nazwa   varchar(30) NOT NULL
);
CREATE TABLE dbo.MIASTA
( id_miasta int IDENTITY(1,1) CONSTRAINT PK_MIASTA PRIMARY KEY,
  kod_woj   char(3) NOT NULL CONSTRAINT FK_MIASTA_WOJ REFERENCES dbo.WOJ(kod_woj),
  nazwa     varchar(30) NOT NULL
);
CREATE TABLE dbo.OSOBY
( id_osoby  int IDENTITY(1,1) CONSTRAINT PK_OSOBY PRIMARY KEY,
  id_miasta int NOT NULL CONSTRAINT FK_OSOBY_MIASTA REFERENCES dbo.MIASTA(id_miasta),
  imie      varchar(20) NOT NULL,
  nazwisko  varchar(30) NOT NULL
);
CREATE TABLE dbo.ETATY
( id_etatu  int IDENTITY(1,1) CONSTRAINT PK_ETATY PRIMARY KEY,
  id_osoby  int NOT NULL CONSTRAINT FK_ETATY_OSOBY REFERENCES dbo.OSOBY(id_osoby),
  stanowisko varchar(60) NOT NULL,
  pensja     money       NOT NULL,
  [od]       datetime    NOT NULL,
  [do]       datetime    NULL
);

INSERT INTO dbo.WOJ(kod_woj,nazwa)
VALUES (''MAZ'',''Mazowieckie''), (''POM'',''Pomorskie''), (''???'',''<Nieznane>'');

INSERT INTO dbo.MIASTA(kod_woj,nazwa)
VALUES (''MAZ'',''WESOŁA''), (''MAZ'',''WARSZAWA''), (''POM'',''GDAŃSK''), (''POM'',''SOPOT'');

DECLARE @id_wes int = (SELECT id_miasta FROM dbo.MIASTA WHERE nazwa=''WESOŁA'');
DECLARE @id_wwa int = (SELECT id_miasta FROM dbo.MIASTA WHERE nazwa=''WARSZAWA'');
DECLARE @id_gda int = (SELECT id_miasta FROM dbo.MIASTA WHERE nazwa=''GDAŃSK'');
DECLARE @id_sop int = (SELECT id_miasta FROM dbo.MIASTA WHERE nazwa=''SOPOT'');

INSERT INTO dbo.OSOBY(imie,nazwisko,id_miasta)
VALUES (''Maciej'',''Stodolski'',@id_wes),
       (''Jacek'',''Korytkowski'',@id_wwa),
       (''Miś'',''Nieznany'',@id_gda),
       (''Król'',''Neptun'',@id_sop),
       (''Już'',''Niepracujący'',@id_wwa);

DECLARE @id_ms int = (SELECT id_osoby FROM dbo.OSOBY WHERE imie=''Maciej'' AND nazwisko=''Stodolski'');
DECLARE @id_jk int = (SELECT id_osoby FROM dbo.OSOBY WHERE imie=''Jacek''  AND nazwisko=''Korytkowski'');
DECLARE @id_jn int = (SELECT id_osoby FROM dbo.OSOBY WHERE imie=''Już''    AND nazwisko=''Niepracujący'');
DECLARE @id_kn int = (SELECT id_osoby FROM dbo.OSOBY WHERE imie=''Król''   AND nazwisko=''Neptun'');

INSERT INTO dbo.ETATY(id_osoby,stanowisko,pensja,[od],[do]) VALUES
(@id_ms,''Doktorant'',  600,''19940101'',''19980101''),
(@id_ms,''Asystent'',  1600,''19980102'',''20000101''),
(@id_ms,''Adjunkt'',   3200,''20000102'',NULL),
(@id_ms,''Sprzątacz'', 2200,''19990101'',NULL),
(@id_jk,''Adjunkt'',   3200,''20011110'',NULL),
(@id_jn,''Dyrektor'', 50000,''20000101'',''20021021''),
(@id_kn,''Prezes'',   65200,''20041023'',NULL);
';
  EXEC sys.sp_executesql @sql;
END
GO

/* 5) Seeding w trzech bazach */
EXEC dbo.pr_seed_baz_bazowe_tabele @db = N'B25_DB1';
EXEC dbo.pr_seed_baz_bazowe_tabele @db = N'B25_DB2';
EXEC dbo.pr_seed_baz_bazowe_tabele @db = N'B25_DB3';
GO

/* 6) Dodatkowe rekordy tylko w B25_DB3 */
DECLARE @extra nvarchar(max) = N'
USE [B25_DB3];
DECLARE @id_wars int = (SELECT TOP(1) id_miasta FROM dbo.MIASTA WHERE nazwa = ''WARSZAWA'');
DECLARE @id1 int, @id2 int;

INSERT INTO dbo.OSOBY(imie,nazwisko,id_miasta)
VALUES (''Anna'',''Kowalska'',@id_wars),
       (''Piotr'',''Nowak'',  @id_wars);

SET @id2 = IDENT_CURRENT(''dbo.OSOBY'');
SET @id1 = @id2 - 1;

INSERT INTO dbo.ETATY(id_osoby,stanowisko,pensja,[od],[do]) VALUES
(@id1,''Specjalista'',         8000,''20220101'',NULL),
(@id1,''Starszy Specjalista'',11000,''20240101'',NULL),
(@id2,''Inżynier'',            9000,''20230115'',NULL);
';
EXEC sys.sp_executesql @extra;
GO

IF OBJECT_ID('dbo.pr_run_db_check','P') IS NOT NULL DROP PROCEDURE dbo.pr_run_db_check;
IF OBJECT_ID('dbo.pr_run_db_check_v2012','P') IS NOT NULL DROP PROCEDURE dbo.pr_run_db_check_v2012;
GO

/* 7) Snapshot – PROCEDURA: osobny batch i 1. instrukcja w batchu */
USE B25_ADM;
GO
IF OBJECT_ID('dbo.pr_run_db_check','P') IS NOT NULL DROP PROCEDURE dbo.pr_run_db_check;
IF OBJECT_ID('dbo.pr_run_db_check_v2012','P') IS NOT NULL DROP PROCEDURE dbo.pr_run_db_check_v2012;
GO

CREATE PROCEDURE dbo.pr_run_db_check_v2012
  @db_list nvarchar(max) = N'B25_DB1,B25_DB2,B25_DB3,B25_DB4,B25_DB5',
  @opis    nvarchar(50)  = N'Snapshot'
AS
BEGIN
  SET NOCOUNT ON;

  -- splitter CSV (2012)
  DECLARE @xml xml = N'<x><y>' + REPLACE(@db_list, N',', N'</y><y>') + N'</y></x>';
  DECLARE @dbs TABLE (db sysname PRIMARY KEY);
  INSERT INTO @dbs(db)
  SELECT DISTINCT LTRIM(RTRIM(T.c.value('.','nvarchar(128)')))
  FROM @xml.nodes('/x/y') AS T(c)
  WHERE LTRIM(RTRIM(T.c.value('.','nvarchar(128)'))) <> N'';

  DECLARE @db sysname, @sql nvarchar(max);
  DECLARE @t TABLE (tb_nam sysname, liczba int);  -- bufor ZADANY raz

  DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT db FROM @dbs;
  OPEN c; FETCH NEXT FROM c INTO @db;

  WHILE @@FETCH_STATUS = 0
  BEGIN
    IF DB_ID(@db) IS NOT NULL
    BEGIN
      -- wyczyść bufor dla TEJ iteracji
      DELETE FROM @t;

      -- nagłówek pomiaru
      INSERT INTO dbo.DB_CHECK(db_nam, opis) VALUES (@db, @opis);
      DECLARE @check_id int = SCOPE_IDENTITY();

      -- zliczenie z metadanych w TEJ bazie
      SET @sql = N'
        SELECT t.name AS tb_nam,
               CAST(SUM(CASE WHEN p.index_id IN (0,1) THEN p.[rows] ELSE 0 END) AS int) AS liczba
        FROM ' + QUOTENAME(@db) + N'.sys.tables t
        JOIN ' + QUOTENAME(@db) + N'.sys.partitions p ON p.[object_id] = t.[object_id]
        GROUP BY t.name
        ORDER BY t.name;';

      INSERT INTO @t(tb_nam, liczba)
      EXEC sys.sp_executesql @sql;

      INSERT INTO dbo.DB_CHECK_ITEMS(check_id, tb_nam, liczba_reordow)
      SELECT @check_id, tb_nam, liczba
      FROM @t;
    END

    FETCH NEXT FROM c INTO @db;
  END

  CLOSE c; DEALLOCATE c;
END
GO

CREATE PROCEDURE dbo.pr_run_db_check
  @db_list nvarchar(max) = N'B25_DB1,B25_DB2,B25_DB3,B25_DB4,B25_DB5',
  @opis    nvarchar(50)  = N'Pomiar liczby rekordów'
AS
BEGIN
  EXEC dbo.pr_run_db_check_v2012 @db_list=@db_list, @opis=@opis;
END
GO



/* 9) Uruchom snapshot + kontrola */
EXEC dbo.pr_run_db_check
  @db_list = N'B25_DB1,B25_DB2,B25_DB3,B25_DB4,B25_DB5',
  @opis    = N'Z2 – snapshot #1';

SELECT TOP 20 * FROM dbo.DB_CHECK ORDER BY check_id DESC;
SELECT TOP 50 * FROM dbo.DB_CHECK_ITEMS ORDER BY tb_check_d_stamp DESC, check_id DESC;


/*
check_id    db_nam      d_stamp                  opis              usr         s_usr                
----------  ----------  -----------------------  ----------------  ----------  ---------------------
66          B25_DB5     2025-10-25 11:09:40.400  Z2 – snapshot #1  dbo         DESKTOP-C2629FK\Stasd
65          B25_DB4     2025-10-25 11:09:40.247  Z2 – snapshot #1  dbo         DESKTOP-C2629FK\Stasd
64          B25_DB3     2025-10-25 11:09:40.103  Z2 – snapshot #1  dbo         DESKTOP-C2629FK\Stasd
63          B25_DB2     2025-10-25 11:09:39.953  Z2 – snapshot #1  dbo         DESKTOP-C2629FK\Stasd
62          B25_DB1     2025-10-25 11:09:39.787  Z2 – snapshot #1  dbo         DESKTOP-C2629FK\Stasd
61          B25_DB5     2025-10-25 11:04:40.370  Z2 – snapshot #1  dbo         DESKTOP-C2629FK\Stasd
60          B25_DB4     2025-10-25 11:04:40.223  Z2 – snapshot #1  dbo         DESKTOP-C2629FK\Stasd
59          B25_DB3     2025-10-25 11:04:40.077  Z2 – snapshot #1  dbo         DESKTOP-C2629FK\Stasd
58          B25_DB2     2025-10-25 11:04:39.927  Z2 – snapshot #1  dbo         DESKTOP-C2629FK\Stasd
57          B25_DB1     2025-10-25 11:04:39.767  Z2 – snapshot #1  dbo         DESKTOP-C2629FK\Stasd
56          B25_DB5     2025-10-25 11:00:40.847  Z2 – snapshot #1  dbo         DESKTOP-C2629FK\Stasd
55          B25_DB4     2025-10-25 11:00:40.703  Z2 – snapshot #1  dbo         DESKTOP-C2629FK\Stasd
54          B25_DB3     2025-10-25 11:00:40.547  Z2 – snapshot #1  dbo         DESKTOP-C2629FK\Stasd
53          B25_DB2     2025-10-25 11:00:40.403  Z2 – snapshot #1  dbo         DESKTOP-C2629FK\Stasd
52          B25_DB1     2025-10-25 11:00:40.253  Z2 – snapshot #1  dbo         DESKTOP-C2629FK\Stasd
51          B25_DB5     2025-10-25 10:49:39.970  Z2 – snapshot #1  dbo         DESKTOP-C2629FK\Stasd
50          B25_DB4     2025-10-25 10:49:39.827  Z2 – snapshot #1  dbo         DESKTOP-C2629FK\Stasd
49          B25_DB3     2025-10-25 10:49:39.673  Z2 – snapshot #1  dbo         DESKTOP-C2629FK\Stasd
48          B25_DB2     2025-10-25 10:49:39.537  Z2 – snapshot #1  dbo         DESKTOP-C2629FK\Stasd
47          B25_DB1     2025-10-25 10:49:39.380  Z2 – snapshot #1  dbo         DESKTOP-C2629FK\Stasd
((20 rows affected))

Result Set 12-1
========================================

check_id    tb_nam      liczba_reordow  tb_check_d_stamp       
----------  ----------  --------------  -----------------------
64          ETATY       10              2025-10-25 11:09:40.247
64          MIASTA      4               2025-10-25 11:09:40.247
64          OSOBY       7               2025-10-25 11:09:40.247
64          WOJ         3               2025-10-25 11:09:40.247
63          ETATY       7               2025-10-25 11:09:40.103
63          MIASTA      4               2025-10-25 11:09:40.103
63          OSOBY       5               2025-10-25 11:09:40.103
63          WOJ         3               2025-10-25 11:09:40.103
62          ETATY       7               2025-10-25 11:09:39.953
62          MIASTA      4               2025-10-25 11:09:39.953
62          OSOBY       5               2025-10-25 11:09:39.953
62          WOJ         3               2025-10-25 11:09:39.953
61          ETATY       7               2025-10-25 11:04:40.517
61          OSOBY       5               2025-10-25 11:04:40.517
61          MIASTA      4               2025-10-25 11:04:40.517
61          WOJ         3               2025-10-25 11:04:40.517
60          ETATY       7               2025-10-25 11:04:40.370
60          OSOBY       5               2025-10-25 11:04:40.370
60          MIASTA      4               2025-10-25 11:04:40.370
60          WOJ         3               2025-10-25 11:04:40.370
59          ETATY       7               2025-10-25 11:04:40.223
59          OSOBY       5               2025-10-25 11:04:40.223
59          MIASTA      4               2025-10-25 11:04:40.223
59          WOJ         3               2025-10-25 11:04:40.223
58          MIASTA      4               2025-10-25 11:04:40.077
58          WOJ         3               2025-10-25 11:04:40.077
58          ETATY       7               2025-10-25 11:04:40.077
58          OSOBY       5               2025-10-25 11:04:40.077
57          ETATY       7               2025-10-25 11:04:39.927
57          MIASTA      4               2025-10-25 11:04:39.927
57          OSOBY       5               2025-10-25 11:04:39.927
57          WOJ         3               2025-10-25 11:04:39.927
56          ETATY       7               2025-10-25 11:00:41.013
56          MIASTA      4               2025-10-25 11:00:41.013
56          OSOBY       5               2025-10-25 11:00:41.013
56          WOJ         3               2025-10-25 11:00:41.013
56          ETATY       7               2025-10-25 11:00:41.013
56          MIASTA      4               2025-10-25 11:00:41.013
56          OSOBY       5               2025-10-25 11:00:41.013
56          WOJ         3               2025-10-25 11:00:41.013
56          ETATY       10              2025-10-25 11:00:41.013
56          MIASTA      4               2025-10-25 11:00:41.013
56          OSOBY       7               2025-10-25 11:00:41.013
56          WOJ         3               2025-10-25 11:00:41.013
55          ETATY       7               2025-10-25 11:00:40.847
55          MIASTA      4               2025-10-25 11:00:40.847
55          OSOBY       5               2025-10-25 11:00:40.847
55          WOJ         3               2025-10-25 11:00:40.847
55          ETATY       7               2025-10-25 11:00:40.847
*/


USE B25_ADM;
GO

/* Sprzątanie starych wersji */
IF OBJECT_ID('dbo.pr_db_check_one','P') IS NOT NULL DROP PROCEDURE dbo.pr_db_check_one;
IF OBJECT_ID('dbo.pr_db_check_all','P') IS NOT NULL DROP PROCEDURE dbo.pr_db_check_all;
GO

/* 4.2 – POMIAR DLA JEDNEJ BAZY (szybko, bez kursora po tabelach) */
CREATE PROCEDURE dbo.pr_db_check_one
  @db   sysname,
  @opis nvarchar(50) = N'Procedura 4.2'
AS
BEGIN
  SET NOCOUNT ON;

  IF DB_ID(@db) IS NULL
  BEGIN
    RAISERROR(N'Baza %s nie istnieje.', 16, 1, @db);
    RETURN;
  END;

  -- 1) Nagłówek pomiaru
  INSERT INTO B25_ADM.dbo.DB_CHECK(opis, db_nam) VALUES (@opis, @db);
  DECLARE @check_id int = SCOPE_IDENTITY();

  -- 2) Jednym strzałem pobierz liczbę rekordów w każdej tabeli użytkownika
  DECLARE @sql nvarchar(max) = N'
    INSERT INTO B25_ADM.dbo.DB_CHECK_ITEMS(check_id, tb_nam, liczba_reordow)
    SELECT ' + CAST(@check_id AS nvarchar(20)) + N',
           QUOTENAME(s.name) + ''.'' + QUOTENAME(t.name) AS tb_nam,
           CAST(SUM(CASE WHEN p.index_id IN (0,1) THEN p.[rows] ELSE 0 END) AS int) AS liczba
    FROM ' + QUOTENAME(@db) + N'.sys.tables     AS t
    JOIN ' + QUOTENAME(@db) + N'.sys.schemas    AS s ON s.schema_id  = t.schema_id
    JOIN ' + QUOTENAME(@db) + N'.sys.partitions AS p ON p.[object_id]= t.[object_id]
    WHERE t.is_ms_shipped = 0
    GROUP BY s.name, t.name
    ORDER BY s.name, t.name;';

  EXEC sys.sp_executesql @sql;
END
GO

/* 4.2 – POMIAR DLA WSZYSTKICH BAZ UŻYTKOWNIKA (bez admin, domyślnie tylko B25_DB%) */
CREATE PROCEDURE dbo.pr_db_check_all
  @opis nvarchar(50) = N'Procedura 4.2 – all DBs',
  @wzor nvarchar(100) = N'B25_DB%'  -- ustaw N'%' jeśli chcesz wszystkie nie-admin
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @db sysname;
  DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT d.name
    FROM sys.databases d
    WHERE d.name NOT IN (N'master',N'model',N'msdb',N'tempdb',N'B25_ADM')
      AND d.state = 0              -- ONLINE
      AND d.is_read_only = 0
      AND d.name LIKE @wzor;       -- filtr na Twoje bazy

  OPEN cur; FETCH NEXT FROM cur INTO @db;

  WHILE @@FETCH_STATUS = 0
  BEGIN
    BEGIN TRY
      EXEC dbo.pr_db_check_one @db=@db, @opis=@opis;
    END TRY
    BEGIN CATCH
      PRINT N'Pominięto bazę ' + @db + N' : ' + ERROR_MESSAGE();
    END CATCH;

    FETCH NEXT FROM cur INTO @db;
  END

  CLOSE cur; DEALLOCATE cur;
END
GO


-- ✅ Pomiar dla jednej bazy
EXEC B25_ADM.dbo.pr_db_check_one @db = N'B25_DB3', @opis = N'4.2 – pojedyncza baza';

-- ✅ Pomiar dla wszystkich baz użytkownika (bez administracyjnych)
EXEC B25_ADM.dbo.pr_db_check_all @opis = N'4.2 – wszystkie B25_DB', @wzor = N'B25_DB%';

-- ✅ Podgląd wyników (ostatnie pomiary)
SELECT TOP 5 * FROM B25_ADM.dbo.DB_CHECK ORDER BY check_id DESC;
SELECT * FROM B25_ADM.dbo.DB_CHECK_ITEMS 
WHERE check_id = (SELECT MAX(check_id) FROM B25_ADM.dbo.DB_CHECK);

/*
Result Set 16-0
========================================

check_id    db_nam      d_stamp                  opis                    usr         s_usr                
----------  ----------  -----------------------  ----------------------  ----------  ---------------------
152         B25_DB5     2025-10-25 12:29:39.333  4.2 – wszystkie B25_DB  dbo         DESKTOP-C2629FK\Stasd
151         B25_DB4     2025-10-25 12:29:39.130  4.2 – wszystkie B25_DB  dbo         DESKTOP-C2629FK\Stasd
150         B25_DB3     2025-10-25 12:29:38.943  4.2 – wszystkie B25_DB  dbo         DESKTOP-C2629FK\Stasd
149         B25_DB2     2025-10-25 12:29:38.710  4.2 – wszystkie B25_DB  dbo         DESKTOP-C2629FK\Stasd
148         B25_DB1     2025-10-25 12:29:38.517  4.2 – wszystkie B25_DB  dbo         DESKTOP-C2629FK\Stasd
((5 rows affected))

Result Set 16-1
========================================

check_id    tb_nam      liczba_reordow  tb_check_d_stamp
*/

-- 4.3
USE B25_ADM;
GO

-- 🔹 Jeśli istnieje poprzednia wersja, usuń
IF OBJECT_ID('dbo.pr_db_check_global','P') IS NOT NULL
    DROP PROCEDURE dbo.pr_db_check_global;
GO

/* =========================================================
   4.3 – GLOBALNY POMIAR DLA WSZYSTKICH BAZ
   - pomija bazy systemowe (master, model, msdb, tempdb, B25_ADM)
   - wywołuje procedurę z punktu 4.2 (pr_db_check_one)
   ========================================================= */
CREATE PROCEDURE dbo.pr_db_check_global
  @opis nvarchar(50) = N'4.3 – globalny pomiar wszystkich baz'
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @db sysname;

  DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT name
    FROM sys.databases
    WHERE name NOT IN (N'master', N'model', N'msdb', N'tempdb', N'B25_ADM')
      AND state = 0           -- tylko ONLINE
      AND is_read_only = 0;   -- tylko RW

  OPEN cur; FETCH NEXT FROM cur INTO @db;

  WHILE @@FETCH_STATUS = 0
  BEGIN
    BEGIN TRY
      EXEC dbo.pr_db_check_one @db=@db, @opis=@opis;   -- 🔹 wywołanie z 4.2
      PRINT N'✔ Zliczono tabele w bazie: ' + @db;
    END TRY
    BEGIN CATCH
      PRINT N'⚠ Pominięto bazę ' + @db + N' z powodu błędu: ' + ERROR_MESSAGE();
    END CATCH;

    FETCH NEXT FROM cur INTO @db;
  END

  CLOSE cur; DEALLOCATE cur;
END
GO


-- ✅ Uruchomienie procedury 4.3 (dla wszystkich baz nie-admin)
EXEC B25_ADM.dbo.pr_db_check_global @opis = N'4.3 – pomiar globalny';


SELECT TOP 10 * FROM B25_ADM.dbo.DB_CHECK ORDER BY check_id DESC;
SELECT * FROM B25_ADM.dbo.DB_CHECK_ITEMS
WHERE check_id = (SELECT MAX(check_id) FROM B25_ADM.dbo.DB_CHECK)
ORDER BY tb_nam;

/*
Result Set 16-0
========================================

check_id    db_nam      d_stamp                  opis                    usr         s_usr                
----------  ----------  -----------------------  ----------------------  ----------  ---------------------
152         B25_DB5     2025-10-25 12:29:39.333  4.2 – wszystkie B25_DB  dbo         DESKTOP-C2629FK\Stasd
151         B25_DB4     2025-10-25 12:29:39.130  4.2 – wszystkie B25_DB  dbo         DESKTOP-C2629FK\Stasd
150         B25_DB3     2025-10-25 12:29:38.943  4.2 – wszystkie B25_DB  dbo         DESKTOP-C2629FK\Stasd
149         B25_DB2     2025-10-25 12:29:38.710  4.2 – wszystkie B25_DB  dbo         DESKTOP-C2629FK\Stasd
148         B25_DB1     2025-10-25 12:29:38.517  4.2 – wszystkie B25_DB  dbo         DESKTOP-C2629FK\Stasd
((5 rows affected))

Result Set 16-1
========================================

check_id    tb_nam      liczba_reordow  tb_check_d_stamp
*/


-- Czysta historia: 1 wiersz na check_id (bierze MAX z duplikatów)
SELECT c.db_nam, i.tb_nam, c.check_id, c.d_stamp, MAX(i.liczba_reordow) AS liczba_reordow
FROM B25_ADM.dbo.DB_CHECK c
JOIN B25_ADM.dbo.DB_CHECK_ITEMS i ON i.check_id = c.check_id
WHERE c.db_nam = N'B25_DB3' AND REPLACE(REPLACE(i.tb_nam,'[',''),']','') IN (N'ETATY', N'dbo.ETATY')
GROUP BY c.db_nam, i.tb_nam, c.check_id, c.d_stamp
ORDER BY c.d_stamp, c.check_id;

;WITH d AS (
  SELECT i.*,
         ROW_NUMBER() OVER (PARTITION BY i.check_id, REPLACE(REPLACE(i.tb_nam,'[',''),']','') ORDER BY i.tb_check_d_stamp, i.tb_nam) AS rn
  FROM B25_ADM.dbo.DB_CHECK c
  JOIN B25_ADM.dbo.DB_CHECK_ITEMS i ON i.check_id = c.check_id
  WHERE c.db_nam = N'B25_DB3' AND REPLACE(REPLACE(i.tb_nam,'[',''),']','') IN (N'ETATY', N'dbo.ETATY')
)
DELETE FROM d WHERE rn > 1;

-- 4.4
USE B25_ADM;
GO
IF OBJECT_ID('dbo.pr_db_check_history','P') IS NOT NULL
    DROP PROCEDURE dbo.pr_db_check_history;
GO
CREATE PROCEDURE dbo.pr_db_check_history
    @db    sysname,          -- nazwa bazy, np. N'B25_DB3'
    @table nvarchar(256)     -- nazwa tabeli: 'ETATY' lub 'dbo.ETATY'
AS
BEGIN
    SET NOCOUNT ON;

    -- Normalizacja nazwy tabeli (usuń nawiasy [], wyciągnij schemat)
    DECLARE @t_norm nvarchar(256) = REPLACE(REPLACE(@table, N'[', N''), N']', N'');
    DECLARE @schema sysname, @tab sysname;

    IF CHARINDEX(N'.', @t_norm) > 0
    BEGIN
        SET @schema = PARSENAME(@t_norm, 2);
        SET @tab    = PARSENAME(@t_norm, 1);
    END
    ELSE
    BEGIN
        SET @schema = N'dbo';
        SET @tab    = @t_norm;
    END

    DECLARE @tb_quoted  nvarchar(300) = QUOTENAME(@schema) + N'.' + QUOTENAME(@tab);
    DECLARE @tab_only_q nvarchar(300) = QUOTENAME(@tab);
    DECLARE @tb_plain   nvarchar(300) = @schema + N'.' + @tab;

    ;WITH H AS
    (
        SELECT
            c.db_nam,
            i.tb_nam,
            c.check_id,
            c.d_stamp,
            i.liczba_reordow
        FROM B25_ADM.dbo.DB_CHECK        AS c
        JOIN B25_ADM.dbo.DB_CHECK_ITEMS  AS i
              ON i.check_id = c.check_id
        WHERE c.db_nam = @db
          AND (
                i.tb_nam = @tb_quoted                          -- [schema].[tabela]
             OR i.tb_nam = @tab_only_q                         -- [tabela]
             OR REPLACE(REPLACE(i.tb_nam,N'[',N''),N']',N'') IN (@tb_plain, @tab)  -- schema.tabela lub tabela
          )
    )
    SELECT db_nam, tb_nam, check_id, d_stamp, liczba_reordow
    FROM H
    ORDER BY d_stamp, check_id;

    IF @@ROWCOUNT = 0
        RAISERROR(N'Brak historii dla bazy %s i tabeli %s.', 16, 1, @db, @table);
END
GO



-- Historia ETATY w B25_DB3
EXEC B25_ADM.dbo.pr_db_check_history @db=N'B25_DB3', @table=N'ETATY';

-- Historia z podanym schematem (również zadziała)
EXEC B25_ADM.dbo.pr_db_check_history @db=N'B25_DB3', @table=N'dbo.ETATY';


/*
db_nam      tb_nam         check_id    d_stamp                  liczba_reordow
----------  -------------  ----------  -----------------------  --------------
B25_DB3     ETATY          49          2025-10-25 10:49:39.673  7             
B25_DB3     ETATY          49          2025-10-25 10:49:39.673  7             
B25_DB3     ETATY          49          2025-10-25 10:49:39.673  10            
B25_DB3     ETATY          54          2025-10-25 11:00:40.547  7             
B25_DB3     ETATY          54          2025-10-25 11:00:40.547  7             
B25_DB3     ETATY          54          2025-10-25 11:00:40.547  10            
B25_DB3     ETATY          59          2025-10-25 11:04:40.077  7             
B25_DB3     ETATY          64          2025-10-25 11:09:40.103  10            
B25_DB3     ETATY          69          2025-10-25 11:59:47.990  10            
B25_DB3     [dbo].[ETATY]  72          2025-10-25 11:59:48.507  10            
B25_DB3     [dbo].[ETATY]  96          2025-10-25 11:59:51.420  10            
B25_DB3     ETATY          101         2025-10-25 12:06:49.500  10            
B25_DB3     [dbo].[ETATY]  104         2025-10-25 12:06:50.110  10            
B25_DB3     [dbo].[ETATY]  128         2025-10-25 12:06:53.437  10            
B25_DB3     ETATY          133         2025-10-25 12:18:32.693  10            
B25_DB3     [dbo].[ETATY]  136         2025-10-25 12:18:33.200  10            
B25_DB3     [dbo].[ETATY]  139         2025-10-25 12:18:33.830  10            
B25_DB3     ETATY          144         2025-10-25 12:29:37.740  10            
B25_DB3     [dbo].[ETATY]  147         2025-10-25 12:29:38.260  10            
B25_DB3     [dbo].[ETATY]  150         2025-10-25 12:29:38.943  10            
B25_DB3     ETATY          155         2025-10-25 12:34:18.480  10            
B25_DB3     [dbo].[ETATY]  158         2025-10-25 12:34:18.967  10            
B25_DB3     [dbo].[ETATY]  161         2025-10-25 12:34:19.543  10            
B25_DB3     [dbo].[ETATY]  187         2025-10-25 12:34:25.317  10            
B25_DB3     ETATY          192         2025-10-25 12:39:25.243  10            
B25_DB3     [dbo].[ETATY]  195         2025-10-25 12:39:25.760  10            
B25_DB3     [dbo].[ETATY]  198         2025-10-25 12:39:26.320  10            
B25_DB3     [dbo].[ETATY]  224         2025-10-25 12:39:30.953  10            
B25_DB3     ETATY          229         2025-10-25 12:43:21.243  10            
B25_DB3     [dbo].[ETATY]  232         2025-10-25 12:43:21.757  10            
B25_DB3     [dbo].[ETATY]  235         2025-10-25 12:43:22.380  10            
((31 rows affected))

Result Set 22-1
========================================

db_nam      tb_nam         check_id    d_stamp                  liczba_reordow
----------  -------------  ----------  -----------------------  --------------
B25_DB3     ETATY          49          2025-10-25 10:49:39.673  7             
B25_DB3     ETATY          49          2025-10-25 10:49:39.673  7             
B25_DB3     ETATY          49          2025-10-25 10:49:39.673  10            
B25_DB3     ETATY          54          2025-10-25 11:00:40.547  7             
B25_DB3     ETATY          54          2025-10-25 11:00:40.547  7             
B25_DB3     ETATY          54          2025-10-25 11:00:40.547  10            
B25_DB3     ETATY          59          2025-10-25 11:04:40.077  7             
B25_DB3     ETATY          64          2025-10-25 11:09:40.103  10            
B25_DB3     ETATY          69          2025-10-25 11:59:47.990  10            
B25_DB3     [dbo].[ETATY]  72          2025-10-25 11:59:48.507  10            
B25_DB3     [dbo].[ETATY]  96          2025-10-25 11:59:51.420  10            
B25_DB3     ETATY          101         2025-10-25 12:06:49.500  10            
B25_DB3     [dbo].[ETATY]  104         2025-10-25 12:06:50.110  10            
B25_DB3     [dbo].[ETATY]  128         2025-10-25 12:06:53.437  10            
B25_DB3     ETATY          133         2025-10-25 12:18:32.693  10            
B25_DB3     [dbo].[ETATY]  136         2025-10-25 12:18:33.200  10            
B25_DB3     [dbo].[ETATY]  139         2025-10-25 12:18:33.830  10            
B25_DB3     ETATY          144         2025-10-25 12:29:37.740  10            
B25_DB3     [dbo].[ETATY]  147         2025-10-25 12:29:38.260  10            
B25_DB3     [dbo].[ETATY]  150         2025-10-25 12:29:38.943  10            
B25_DB3     ETATY          155         2025-10-25 12:34:18.480  10            
B25_DB3     [dbo].[ETATY]  158         2025-10-25 12:34:18.967  10            
B25_DB3     [dbo].[ETATY]  161         2025-10-25 12:34:19.543  10            
B25_DB3     [dbo].[ETATY]  187         2025-10-25 12:34:25.317  10            
B25_DB3     ETATY          192         2025-10-25 12:39:25.243  10            
B25_DB3     [dbo].[ETATY]  195         2025-10-25 12:39:25.760  10            
B25_DB3     [dbo].[ETATY]  198         2025-10-25 12:39:26.320  10            
B25_DB3     [dbo].[ETATY]  224         2025-10-25 12:39:30.953  10            
B25_DB3     ETATY          229         2025-10-25 12:43:21.243  10            
B25_DB3     [dbo].[ETATY]  232         2025-10-25 12:43:21.757  10 
*/


USE B25_ADM;
GO

/* --- porządkowanie starych wersji --- */
IF OBJECT_ID('dbo.pr_db_check_stats','P') IS NOT NULL DROP PROCEDURE dbo.pr_db_check_stats;
IF OBJECT_ID('dbo.ST_M','P')               IS NOT NULL DROP PROCEDURE dbo.ST_M;
IF OBJECT_ID('dbo.ST_D','P')               IS NOT NULL DROP PROCEDURE dbo.ST_D;
GO

/* =========================================================
   4.5 – porównanie dwóch pomiarów (check_id_1 vs check_id_2)
   ========================================================= */
CREATE PROCEDURE dbo.pr_db_check_stats
  @check_id_1 int,
  @check_id_2 int
AS
BEGIN
  SET NOCOUNT ON;

  IF NOT EXISTS (SELECT 1 FROM dbo.DB_CHECK WHERE check_id=@check_id_1)
     OR NOT EXISTS (SELECT 1 FROM dbo.DB_CHECK WHERE check_id=@check_id_2)
  BEGIN
    RAISERROR(N'Check_id nie istniej w B25_ADM.dbo.DB_CHECK', 16, 3);
    RETURN;
  END;

  ;WITH c1 AS (
      SELECT c.db_nam, i.tb_nam, i.liczba_reordow
      FROM dbo.DB_CHECK c
      JOIN dbo.DB_CHECK_ITEMS i ON i.check_id=c.check_id
      WHERE c.check_id=@check_id_1
  ),
  c2 AS (
      SELECT c.db_nam, i.tb_nam, i.liczba_reordow
      FROM dbo.DB_CHECK c
      JOIN dbo.DB_CHECK_ITEMS i ON i.check_id=c.check_id
      WHERE c.check_id=@check_id_2
  ),
  j AS (
      SELECT 
        COALESCE(c2.db_nam, c1.db_nam) AS baza,
        COALESCE(c2.tb_nam, c1.tb_nam) AS tabela,
        ISNULL(c1.liczba_reordow,0)    AS liczba_reordow_dla_check_1,
        ISNULL(c2.liczba_reordow,0)    AS liczba_reordow_dla_check_2,
        ISNULL(c2.liczba_reordow,0) - ISNULL(c1.liczba_reordow,0) AS przyrost
      FROM c1
      FULL OUTER JOIN c2
        ON c1.db_nam=c2.db_nam AND c1.tb_nam=c2.tb_nam
  )
  -- Wynik 1: pełna tabela porównawcza
  SELECT baza, tabela, liczba_reordow_dla_check_1, liczba_reordow_dla_check_2, przyrost
  FROM j
  ORDER BY baza, tabela;

  -- Wynik 2: największy przyrost w bazie
  ;WITH mx AS (
    SELECT baza, tabela, przyrost,
           ROW_NUMBER() OVER (PARTITION BY baza ORDER BY przyrost DESC, tabela) AS rn
    FROM j
  )
  SELECT baza, tabela, przyrost AS najwiekszy_przyrost_w_bazie_pomiedzy_check1_i_check2
  FROM mx
  WHERE rn=1
  ORDER BY baza;
END
GO

/* =========================================================
   4.5.1 – statystyka MIESIĘCZNA: @parametr_ym = 'YYYYMM'
   ========================================================= */
CREATE PROCEDURE dbo.ST_M
  @parametr_ym nchar(6),
  @baza        nvarchar(100)
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @c1 int = (
    SELECT MIN(c.check_id) FROM dbo.DB_CHECK c
    WHERE CONVERT(nchar(6), c.d_stamp, 112)=@parametr_ym AND c.db_nam=@baza
  );
  DECLARE @c2 int = (
    SELECT MAX(c.check_id) FROM dbo.DB_CHECK c
    WHERE CONVERT(nchar(6), c.d_stamp, 112)=@parametr_ym AND c.db_nam=@baza
  );

  IF @c1 IS NULL OR @c2 IS NULL
  BEGIN
    RAISERROR(N'Brak pomiarów dla wskazanego miesiąca i bazy.',16,6);
    RETURN;
  END;

  EXEC dbo.pr_db_check_stats @check_id_1=@c1, @check_id_2=@c2;
END
GO

/* =========================================================
   4.5.2 – statystyka DZIENNA: @parametr_dzien = 'YYYYMMDD'
   ========================================================= */
CREATE PROCEDURE dbo.ST_D
  @parametr_dzien nchar(8),
  @baza           nvarchar(100)
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @c1 int = (
    SELECT MIN(c.check_id) FROM dbo.DB_CHECK c
    WHERE CONVERT(nchar(8), c.d_stamp, 112)=@parametr_dzien AND c.db_nam=@baza
  );
  DECLARE @c2 int = (
    SELECT MAX(c.check_id) FROM dbo.DB_CHECK c
    WHERE CONVERT(nchar(8), c.d_stamp, 112)=@parametr_dzien AND c.db_nam=@baza
  );

  IF @c1 IS NULL OR @c2 IS NULL
  BEGIN
    RAISERROR(N'Brak pomiarów dla wskazanego dnia i bazy.',16,7);
    RETURN;
  END;

  EXEC dbo.pr_db_check_stats @check_id_1=@c1, @check_id_2=@c2;
END
GO



-- 4.5: porównanie dwóch konkretnych pomiarów
EXEC B25_ADM.dbo.pr_db_check_stats @check_id_1 = 148, @check_id_2 = 152;

-- 4.5.1: przyrost w miesiącu (YYYYMM) dla danej bazy
EXEC B25_ADM.dbo.ST_M @parametr_ym = N'202510', @baza = N'B25_DB3';

-- 4.5.2: przyrost w dniu (YYYYMMDD) dla danej bazy
EXEC B25_ADM.dbo.ST_D @parametr_dzien = N'20251025', @baza = N'B25_DB3';
