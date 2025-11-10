/* ============================================================
   Z2_331720.sql
   Autor: Paweł Myszka
   Nr albumu: 331720
   Dzień zajęć: 2025-10-27
   Cel: Zadanie Z2 - Administracja BD (kompletna wersja do uruchomienia)
   Uruchomić w SQL Server Management Studio lub VS Code (mssql extension)
   Uwaga: Dostęp do systemu plików (C:\BazyDanych\) wymagany do tworzenia plików .mdf/.ldf/.bak
   ============================================================ */

SET NOCOUNT ON;
------------------------------------------------------------
-- 0) Przygotowanie: utwórz folder C:\BazyDanych\ jeśli potrzebujesz
-- (jeśli nie możesz zapisywać tam plików, zmień ścieżki FILE/LOG/BACKUP poniżej)
------------------------------------------------------------

/* ============================
   1) BAZA ADMINISTRACYJNA B25_ADM_PM331720
   (tabele DB_CHECK i DB_CHECK_ITEMS)
   ============================ */
USE master;
GO

IF DB_ID(N'B25_ADM_PM331720') IS NULL
BEGIN
  EXEC('CREATE DATABASE [B25_ADM_PM331720]');
END
GO

USE [B25_ADM_PM331720];
GO

-- Tabela: DB_CHECK
IF OBJECT_ID(N'dbo.DB_CHECK','U') IS NULL
BEGIN
  CREATE TABLE dbo.DB_CHECK
  (
    check_id INT IDENTITY(1,1) PRIMARY KEY,
    db_nam   NVARCHAR(100) NOT NULL,
    d_stamp  DATETIME NOT NULL DEFAULT GETDATE(),
    opis     NVARCHAR(200) NOT NULL,
    [usr]    NVARCHAR(128) NOT NULL DEFAULT USER_NAME(),
    [s_usr]  NVARCHAR(128) NOT NULL DEFAULT SUSER_NAME()
  );
END
GO

-- Tabela: DB_CHECK_ITEMS
IF OBJECT_ID(N'dbo.DB_CHECK_ITEMS','U') IS NULL
BEGIN
  CREATE TABLE dbo.DB_CHECK_ITEMS
  (
    check_id INT NOT NULL,
    tb_nam   NVARCHAR(256) NOT NULL,
    liczba_reordow INT NOT NULL,
    tb_check_d_stamp DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_DB_CHECK_ITEMS__DB_CHECK FOREIGN KEY (check_id)
      REFERENCES dbo.DB_CHECK(check_id)
  );
END
GO

/* ============================
   2) UTWÓRZ 5 BAZ: PM_DB1 .. PM_DB5
   (z unikalnymi nazwami plików danych/logów)
   ============================ */
USE master;
GO

DECLARE @i INT = 1;
WHILE @i <= 5
BEGIN
  DECLARE @dbname SYSNAME = N'PM_DB' + CAST(@i AS NVARCHAR(4));
  IF DB_ID(@dbname) IS NULL
  BEGIN
    DECLARE @sql NVARCHAR(MAX) = N'CREATE DATABASE ' + QUOTENAME(@dbname) +
      N' ON (NAME = N''' + @dbname + N'_Data'', FILENAME = N''D:\stud\sem 5\AdminBazDa\2\' + @dbname + N'_Data.mdf'', SIZE = 20MB, MAXSIZE = 200MB, FILEGROWTH = 10MB) ' +
      N' LOG ON (NAME = N''' + @dbname + N'_Log'', FILENAME = N''D:\stud\sem 5\AdminBazDa\2\' + @dbname + N'_Log.ldf'', SIZE = 10MB, MAXSIZE = 100MB, FILEGROWTH = 5MB);';
    EXEC(@sql);
  END
  SET @i = @i + 1;
END
GO

/* ============================
   3) W trzech bazach (PM_DB1..PM_DB3) utworzymy tabele
   WOJ, MIASTA, OSOBY, ETATY i wypełnimy innymi danymi niż przykład kolegi
   -> użyjemy innych kodów województw i innych imion
   ============================ */

-- Procedura seedująca (dla powtarzalności)
USE master;
GO
IF OBJECT_ID(N'dbo.pr_seed_pm331720','P') IS NOT NULL DROP PROCEDURE dbo.pr_seed_pm331720;
GO

CREATE PROCEDURE dbo.pr_seed_pm331720
  @db SYSNAME
AS
BEGIN
  SET NOCOUNT ON;

  -- bezpieczeństwo: tylko jeśli baza istnieje
  IF DB_ID(@db) IS NULL
  BEGIN
    RAISERROR(N'Baza %s nie istnieje.',16,1,@db);
    RETURN;
  END

  DECLARE @sql NVARCHAR(MAX) = N'
  USE ' + QUOTENAME(@db) + N';
  SET NOCOUNT ON;

  -- usuwamy jeśli istniały
  IF OBJECT_ID(''dbo.ETATY'',''U'') IS NOT NULL DROP TABLE dbo.ETATY;
  IF OBJECT_ID(''dbo.OSOBY'',''U'') IS NOT NULL DROP TABLE dbo.OSOBY;
  IF OBJECT_ID(''dbo.MIASTA'',''U'') IS NOT NULL DROP TABLE dbo.MIASTA;
  IF OBJECT_ID(''dbo.WOJ'',''U'') IS NOT NULL DROP TABLE dbo.WOJ;

  CREATE TABLE dbo.WOJ
  (
    kod_woj CHAR(3) NOT NULL CONSTRAINT PK_WOJ_PM PRIMARY KEY,
    nazwa   NVARCHAR(60) NOT NULL
  );

  CREATE TABLE dbo.MIASTA
  (
    id_miasta INT IDENTITY(1,1) PRIMARY KEY,
    kod_woj   CHAR(3) NOT NULL CONSTRAINT FK_MIASTA_WOJ_PM REFERENCES dbo.WOJ(kod_woj),
    nazwa     NVARCHAR(80) NOT NULL
  );

  CREATE TABLE dbo.OSOBY
  (
    id_osoby INT IDENTITY(1,1) PRIMARY KEY,
    id_miasta INT NOT NULL CONSTRAINT FK_OSOBY_MIASTA_PM REFERENCES dbo.MIASTA(id_miasta),
    imie     NVARCHAR(50) NOT NULL,
    nazwisko NVARCHAR(80) NOT NULL
  );

  CREATE TABLE dbo.ETATY
  (
    id_etatu INT IDENTITY(1,1) PRIMARY KEY,
    id_osoby INT NOT NULL CONSTRAINT FK_ETATY_OSOBY_PM REFERENCES dbo.OSOBY(id_osoby),
    stanowisko NVARCHAR(100) NOT NULL,
    pensja MONEY NOT NULL,
    [od] DATETIME NOT NULL,
    [do] DATETIME NULL
  );

  -- Wstawiamy inne kody woj niż przyjaciel:
  INSERT INTO dbo.WOJ(kod_woj, nazwa)
  VALUES (''WAW'', ''Woj. Warszawskie''), (''LUB'', ''Woj. Lubelskie''), (''SLK'', ''Woj. Śląskie'');

  INSERT INTO dbo.MIASTA(kod_woj, nazwa)
  VALUES (''WAW'', ''WARSZAWA''), (''WAW'', ''ZIELONKA''), (''LUB'', ''LUBLIN''), (''SLK'', ''KATOWICE'');

  INSERT INTO dbo.OSOBY(id_miasta, imie, nazwisko)
  VALUES
   ((SELECT id_miasta FROM dbo.MIASTA WHERE nazwa=''ZIELONKA''),' '','''),
   ((SELECT id_miasta FROM dbo.MIASTA WHERE nazwa=''WARSZAWA''),''Marek'',''Nowak''),
   ((SELECT id_miasta FROM dbo.MIASTA WHERE nazwa=''LUBLIN''),''Ewa'',''Zielińska''),
   ((SELECT id_miasta FROM dbo.MIASTA WHERE nazwa=''KATOWICE''),''Tomasz'',''Bąk''),
   ((SELECT id_miasta FROM dbo.MIASTA WHERE nazwa=''WARSZAWA''),''Karolina'',''Kowalczyk'');

  -- poprawiamy pierwszy pusty wpis (jeśli wystąpił) - usuń te dwa wiersze powyżej jeśli problem
  DELETE FROM dbo.OSOBY WHERE imie = '' '' AND nazwisko = '''';

  DECLARE @idm1 INT = (SELECT TOP 1 id_osoby FROM dbo.OSOBY WHERE imie = ''Marek'' AND nazwisko = ''Nowak'');
  DECLARE @idm2 INT = (SELECT TOP 1 id_osoby FROM dbo.OSOBY WHERE imie = ''Ewa'' AND nazwisko = ''Zielińska'');
  DECLARE @idm3 INT = (SELECT TOP 1 id_osoby FROM dbo.OSOBY WHERE imie = ''Tomasz'' AND nazwisko = ''Bąk'');
  DECLARE @idm4 INT = (SELECT TOP 1 id_osoby FROM dbo.OSOBY WHERE imie = ''Karolina'' AND nazwisko = ''Kowalczyk'');

  INSERT INTO dbo.ETATY(id_osoby, stanowisko, pensja, [od], [do])
  VALUES
   (@idm1, ''Adiunkt'',  4500, ''20180101'', NULL),
   (@idm2, ''Asystent'', 2200, ''20190115'', NULL),
   (@idm3, ''Inżynier'', 5600, ''20200101'', NULL),
   (@idm4, ''Specjalista'', 3800, ''20220301'', NULL);
  ';

  EXEC sys.sp_executesql @sql;
END
GO

-- Wywołujemy procedurę seedującą dla PM_DB1..PM_DB3
EXEC dbo.pr_seed_pm331720 @db = N'PM_DB1';
EXEC dbo.pr_seed_pm331720 @db = N'PM_DB2';
EXEC dbo.pr_seed_pm331720 @db = N'PM_DB3';
GO

/* ============================
   4) W jednej z baz (PM_DB3) dodamy dodatkowe rekordy do OSOBY i ETATY
   ============================ */
USE PM_DB3;
GO

-- Dodamy dodatkowe osoby i etaty (inna zawartość niż u kolegi)
INSERT INTO dbo.OSOBY(id_miasta, imie, nazwisko)
VALUES
  ((SELECT TOP 1 id_miasta FROM dbo.MIASTA WHERE nazwa='WARSZAWA'),'Piotr','Górski'),
  ((SELECT TOP 1 id_miasta FROM dbo.MIASTA WHERE nazwa='WARSZAWA'),'Agnieszka','Leśna');
GO

DECLARE @idp INT = (SELECT TOP 1 id_osoby FROM dbo.OSOBY WHERE imie='Piotr' AND nazwisko='Górski');
DECLARE @ida INT = (SELECT TOP 1 id_osoby FROM dbo.OSOBY WHERE imie='Agnieszka' AND nazwisko='Leśna');

INSERT INTO dbo.ETATY(id_osoby, stanowisko, pensja, [od], [do])
VALUES
  (@idp, 'Kierownik',  11000, '20240101', NULL),
  (@idp, 'Koordynator', 8000, '20230101', NULL),
  (@ida, 'Młodszy Specjalista', 4200, '20230215', NULL);
GO

/* ============================
   5) PROCEDURY DO MONITOROWANIA (4.2, 4.3)
   - pr_pm_check_one(@db)
   - pr_pm_check_all() -> iteruje przez bazy użytkownika
   - pr_pm_check_global() -> wywołuje check_all (ekwiwalent 4.3)
   ============================ */

USE B25_ADM_PM331720;
GO

-- Usuwamy stare procedury o tej samej nazwie
IF OBJECT_ID(N'dbo.pr_pm_check_one','P') IS NOT NULL DROP PROCEDURE dbo.pr_pm_check_one;
IF OBJECT_ID(N'dbo.pr_pm_check_all','P') IS NOT NULL DROP PROCEDURE dbo.pr_pm_check_all;
IF OBJECT_ID(N'dbo.pr_pm_check_global','P') IS NOT NULL DROP PROCEDURE dbo.pr_pm_check_global;
GO

-- 4.2 - pomiar dla jednej bazy (zliczenie rekordów tabel użytkownika)
CREATE PROCEDURE dbo.pr_pm_check_one
  @db sysname,
  @opis NVARCHAR(200) = N'PM331720 - snapshot pojedynczej bazy'
AS
BEGIN
  SET NOCOUNT ON;

  IF DB_ID(@db) IS NULL
  BEGIN
    RAISERROR(N'Baza %s nie istnieje.',16,1,@db);
    RETURN;
  END

  -- nagłówek pomiaru
  INSERT INTO dbo.DB_CHECK(db_nam, opis) VALUES (@db, @opis);
  DECLARE @check_id INT = SCOPE_IDENTITY();

  -- dynamiczny INSERT zbierający liczby w oparciu o sys.partitions (rzetelne)
  DECLARE @sql NVARCHAR(MAX) = N'
    INSERT INTO dbo.DB_CHECK_ITEMS(check_id, tb_nam, liczba_reordow)
    SELECT ' + CAST(@check_id AS NVARCHAR(12)) + N', QUOTENAME(s.name) + ''.'' + QUOTENAME(t.name) AS tb_nam,
           CAST(SUM(CASE WHEN p.index_id IN (0,1) THEN p.[rows] ELSE 0 END) AS INT) AS liczba
    FROM ' + QUOTENAME(@db) + N'.sys.tables t
    JOIN ' + QUOTENAME(@db) + N'.sys.schemas s ON s.schema_id = t.schema_id
    JOIN ' + QUOTENAME(@db) + N'.sys.partitions p ON p.[object_id] = t.[object_id]
    WHERE t.is_ms_shipped = 0
    GROUP BY s.name, t.name
    ORDER BY s.name, t.name;';

  EXEC sys.sp_executesql @sql;
END
GO

-- 4.3 - iteracja po wszystkich użytkowych bazach (pomija systemowe + B25_ADM_PM331720)
CREATE PROCEDURE dbo.pr_pm_check_all
  @opis NVARCHAR(200) = N'PM331720 - snapshot wszystkich user DB'
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @db sysname;

  DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
  SELECT name FROM sys.databases
  WHERE name NOT IN (N'master', N'model', N'msdb', N'tempdb', N'B25_ADM_PM331720')
    AND state = 0 -- online
    AND is_read_only = 0
    AND name LIKE N'PM_DB%';

  OPEN cur;
  FETCH NEXT FROM cur INTO @db;
  WHILE @@FETCH_STATUS = 0
  BEGIN
    BEGIN TRY
      EXEC dbo.pr_pm_check_one @db=@db, @opis=@opis;
      PRINT N'✔ Zliczono tabele w bazie: ' + @db;
    END TRY
    BEGIN CATCH
      PRINT N'⚠ Pominięto bazę ' + @db + N' : ' + ERROR_MESSAGE();
    END CATCH;

    FETCH NEXT FROM cur INTO @db;
  END
  CLOSE cur; DEALLOCATE cur;
END
GO

-- Globalna "skrócona" procedura wywołująca pr_pm_check_all
CREATE PROCEDURE dbo.pr_pm_check_global
  @opis NVARCHAR(200) = N'PM331720 - globalny snapshot'
AS
BEGIN
  SET NOCOUNT ON;
  EXEC dbo.pr_pm_check_all @opis=@opis;
END
GO

/* ============================
   6) PROCEDURA HISTORII (4.4)
   pr_pm_history(@db, @table)
   ============================ */
IF OBJECT_ID(N'dbo.pr_pm_history','P') IS NOT NULL DROP PROCEDURE dbo.pr_pm_history;
GO

CREATE PROCEDURE dbo.pr_pm_history
  @db sysname,
  @table NVARCHAR(256)
AS
BEGIN
  SET NOCOUNT ON;

  -- normalizacja
  DECLARE @t_norm NVARCHAR(256) = REPLACE(REPLACE(@table, N'[', N''), N']', N'');
  DECLARE @schema SYSNAME, @tab SYSNAME;
  IF CHARINDEX('.', @t_norm) > 0
  BEGIN
    SET @schema = PARSENAME(@t_norm, 2);
    SET @tab    = PARSENAME(@t_norm, 1);
  END
  ELSE
  BEGIN
    SET @schema = N'dbo';
    SET @tab = @t_norm;
  END

  DECLARE @tb_quoted NVARCHAR(300) = QUOTENAME(@schema) + N'.' + QUOTENAME(@tab);
  DECLARE @tab_only_q NVARCHAR(300) = QUOTENAME(@tab);
  DECLARE @tb_plain NVARCHAR(300) = @schema + N'.' + @tab;

  SELECT c.db_nam, i.tb_nam, c.check_id, c.d_stamp, i.liczba_reordow
  FROM dbo.DB_CHECK c
  JOIN dbo.DB_CHECK_ITEMS i ON i.check_id = c.check_id
  WHERE c.db_nam = @db
    AND (
         i.tb_nam = @tb_quoted
         OR i.tb_nam = @tab_only_q
         OR REPLACE(REPLACE(i.tb_nam, N'[', N''), N']', N'') IN (@tb_plain, @tab)
        )
  ORDER BY c.d_stamp, c.check_id;

  IF @@ROWCOUNT = 0
    RAISERROR(N'Brak historii dla bazy %s i tabeli %s', 16, 1, @db, @table);
END
GO

/* ============================
   7) STATYSTYKA PORÓWNAWCZA (4.5)
   pr_pm_stats(@check_id_1, @check_id_2)
   Zwraca: kompletne porównanie i max przyrost w każdej bazie
   ============================ */

IF OBJECT_ID(N'dbo.pr_pm_stats','P') IS NOT NULL DROP PROCEDURE dbo.pr_pm_stats;
GO

CREATE PROCEDURE dbo.pr_pm_stats
  @check_id_1 INT,
  @check_id_2 INT
AS
BEGIN
  SET NOCOUNT ON;

  IF NOT EXISTS(SELECT 1 FROM dbo.DB_CHECK WHERE check_id = @check_id_1)
     OR NOT EXISTS(SELECT 1 FROM dbo.DB_CHECK WHERE check_id = @check_id_2)
  BEGIN
    RAISERROR(N'Check_id nie istniej w B25_ADM_PM331720.dbo.DB_CHECK',16,3);
    RETURN;
  END

  ;WITH c1 AS (
    SELECT c.db_nam, i.tb_nam, i.liczba_reordow
    FROM dbo.DB_CHECK c JOIN dbo.DB_CHECK_ITEMS i ON i.check_id = c.check_id
    WHERE c.check_id = @check_id_1
  ),
  c2 AS (
    SELECT c.db_nam, i.tb_nam, i.liczba_reordow
    FROM dbo.DB_CHECK c JOIN dbo.DB_CHECK_ITEMS i ON i.check_id = c.check_id
    WHERE c.check_id = @check_id_2
  ),
  j AS (
    SELECT COALESCE(c2.db_nam, c1.db_nam) AS baza,
           COALESCE(c2.tb_nam, c1.tb_nam) AS tabela,
           ISNULL(c1.liczba_reordow,0) AS liczba_reordow_dla_check_1,
           ISNULL(c2.liczba_reordow,0) AS liczba_reordow_dla_check_2,
           ISNULL(c2.liczba_reordow,0) - ISNULL(c1.liczba_reordow,0) AS przyrost
    FROM c1 FULL OUTER JOIN c2
      ON c1.db_nam = c2.db_nam AND c1.tb_nam = c2.tb_nam
  )

  -- Wynik 1: pełna tabela porównawcza
  SELECT baza, tabela, liczba_reordow_dla_check_1, liczba_reordow_dla_check_2, przyrost
  FROM j
  ORDER BY baza, tabela;

  -- Wynik 2: maksymalny przyrost na bazę
  ;WITH mx AS (
    SELECT baza, tabela, przyrost,
           ROW_NUMBER() OVER (PARTITION BY baza ORDER BY przyrost DESC, tabela) AS rn
    FROM j
  )
  SELECT baza, tabela AS najwiekszy_przyrost_w_bazie_pomiedzy_check1_i_check2
  FROM mx WHERE rn = 1
  ORDER BY baza;
END
GO

/* ============================
   8) STATYSTYKI MIESIĄCZNE / DZIENNE (4.5.1 / 4.5.2)
   ST_M(@param_ym, @baza) -> param: 'YYYYMM'
   ST_D(@param_day, @baza) -> param: 'YYYYMMDD'
   ============================ */
IF OBJECT_ID(N'dbo.ST_M_PM331720','P') IS NOT NULL DROP PROCEDURE dbo.ST_M_PM331720;
IF OBJECT_ID(N'dbo.ST_D_PM331720','P') IS NOT NULL DROP PROCEDURE dbo.ST_D_PM331720;
GO

CREATE PROCEDURE dbo.ST_M_PM331720
  @parametr_ym NCHAR(6),
  @baza NVARCHAR(100)
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @c1 INT = (SELECT MIN(check_id) FROM dbo.DB_CHECK WHERE CONVERT(NCHAR(6), d_stamp, 112) = @parametr_ym AND db_nam = @baza);
  DECLARE @c2 INT = (SELECT MAX(check_id) FROM dbo.DB_CHECK WHERE CONVERT(NCHAR(6), d_stamp, 112) = @parametr_ym AND db_nam = @baza);

  IF @c1 IS NULL OR @c2 IS NULL
  BEGIN
    RAISERROR(N'Brak pomiarów dla wskazanego miesiąca i bazy.',16,6);
    RETURN;
  END

  EXEC dbo.pr_pm_stats @check_id_1 = @c1, @check_id_2 = @c2;
END
GO

CREATE PROCEDURE dbo.ST_D_PM331720
  @parametr_dzien NCHAR(8),
  @baza NVARCHAR(100)
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @c1 INT = (SELECT MIN(check_id) FROM dbo.DB_CHECK WHERE CONVERT(NCHAR(8), d_stamp, 112) = @parametr_dzien AND db_nam = @baza);
  DECLARE @c2 INT = (SELECT MAX(check_id) FROM dbo.DB_CHECK WHERE CONVERT(NCHAR(8), d_stamp, 112) = @parametr_dzien AND db_nam = @baza);

  IF @c1 IS NULL OR @c2 IS NULL
  BEGIN
    RAISERROR(N'Brak pomiarów dla wskazanego dnia i bazy.',16,7);
    RETURN;
  END

  EXEC dbo.pr_pm_stats @check_id_1 = @c1, @check_id_2 = @c2;
END
GO

/* ============================
   9) PRZYKŁADOWE URUCHOMIENIA / KONTROLE
   - seed i snapshot
   - pokaz wyników
   ============================ */

-- Zrobimy snapshot dla PM_DB1..PM_DB5
EXEC dbo.pr_pm_check_all @opis = N'PM331720 - snapshot #1';
GO

-- Pokaż ostatnie wpisy
SELECT TOP 10 * FROM dbo.DB_CHECK ORDER BY check_id DESC;
SELECT TOP 50 * FROM dbo.DB_CHECK_ITEMS ORDER BY tb_check_d_stamp DESC, check_id DESC;
GO

/* ============================
   10) KOPIA ZAPASOWA (przykład) i SKRYPT PRZYWRACANIA
   (tworzy backup bazy B25_ADM_PM331720)
   ============================ */

-- Upewnij się, że folder backup istnieje:
-- CREATE FOLDER C:\BazyDanych\Backups\ ręcznie przed uruchomieniem lub zmień ścieżkę poniżej

DECLARE @bakfile NVARCHAR(260) = N'D:\stud\sem 5\AdminBazDa\2\B25_ADM_PM331720_backup_' + REPLACE(CONVERT(NVARCHAR(20), GETDATE(), 120), ':', '-') + N'.bak';

BACKUP DATABASE [B25_ADM_PM331720]
TO DISK = @bakfile
WITH INIT, FORMAT, NAME = N'Full backup B25_ADM_PM331720 - PM331720';
GO

-- Przywracanie (przykład) - skomentowane. Jeśli chcesz przywrócić, odkomentuj i ustaw DROP/RESTORE poprawnie.
--USE master;
--ALTER DATABASE [B25_ADM_PM331720] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
--RESTORE DATABASE [B25_ADM_PM331720] FROM DISK = N'C:\BazyDanych\B25_ADM_PM331720_backup_2025-10-27 12-00-00.bak' WITH REPLACE;
--ALTER DATABASE [B25_ADM_PM331720] SET MULTI_USER;

/* ============================
   11) DODATKOWE: Tworzenie loginu SQL i użytkownika w B25_ADM_PM331720
   (opcjonalnie — jeśli masz uprawnienia sysadmin; zmień hasło jeśli chcesz)
   ============================ */

-- UWAGA: poniższe tworzy login SQL - może wymagać uprawnień serwera
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'pm_331720_login')
BEGIN
  CREATE LOGIN pm_331720_login WITH PASSWORD = N'Pm331720@2025';
END
GO

USE B25_ADM_PM331720;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'pm_331720_user')
BEGIN
  CREATE USER pm_331720_user FOR LOGIN pm_331720_login WITH DEFAULT_SCHEMA = dbo;
  -- nadajemy role podstawowe w tej bazie
  ALTER ROLE db_datareader ADD MEMBER pm_331720_user;
  ALTER ROLE db_datawriter ADD MEMBER pm_331720_user;
END
GO

/* ============================
   12) Krótkie instrukcje do oddania:
   - Plik: Z2_331720.sql (ten skrypt)
   - Do sprawozdania: zamieść header Imię/Nazwisko/NrAlbumu/Data oraz krótkie objaśnienie:
     co zrobiłeś: utworzenie 5 baz, seed 3 baz danymi (inne kody woj), dodatkowe rekordy w PM_DB3,
     procedury do snapshotów, procedury historyczne i statystyczne, backup przykładowy.
   ============================ */

-- KONIEC SKRYPTU
PRINT N'Skrypt Z2_331720 zakończony. Autor: Paweł Myszka (331720).';
GO
