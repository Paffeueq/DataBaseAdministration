/*
================================================================================
LABORATORIUM 4 -- SYSTEM ZARZĄDZANIA BACKUPAMI BAZ DANYCH
================================================================================
Autor: Paweł Myszka (nr albumu 331720)
Data: 27 listopada 2025

Celem jest stworzenie systemu do automatycznego backupowania baz danych z:
- Logowaniem w tabeli BK_LOG
- Procedurami do backup'u poszczególnych baz i wszystkich baz
- Procedurą backup'u baz gdzie nastąpił przyrost danych
- Zaplanowaniem procedury w SQL Agent
================================================================================
*/

USE B25_ADM_PM331720
GO

-- ============================================================================
-- CZĘŚĆ 1: TABELA LOGOWANIA BACKUPÓW
-- ============================================================================

-- Sprawdzenie i usunięcie tabeli jeśli istnieje (do czyszczenia)
IF OBJECT_ID('dbo.BK_LOG', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.BK_LOG
END
GO

-- Tworzenie tabeli BK_LOG do przechowania dziennika backupów
CREATE TABLE dbo.BK_LOG
(
    bk_id INT NOT NULL IDENTITY(1,1) 
        CONSTRAINT PK_BK_LOG PRIMARY KEY,
    nazwa_b NVARCHAR(100) NOT NULL,           -- Nazwa bazy danych
    nazwa_pliku_bk NVARCHAR(200) NOT NULL,    -- Pełna ścieżka i nazwa pliku backup
    kto NVARCHAR(100) NOT NULL DEFAULT USER_NAME(),     -- Użytkownik
    skad NVARCHAR(100) NOT NULL DEFAULT HOST_NAME(),    -- Host serwera
    kiedy DATETIME NOT NULL DEFAULT GETDATE(),           -- Data/czas backup
    status NVARCHAR(50) DEFAULT 'SUCCESS',    -- Status: SUCCESS, FAILED
    err_msg NVARCHAR(500)                     -- Komunikat błędu jeśli był
);

PRINT 'Tabela BK_LOG utworzona pomyślnie'
GO

-- ============================================================================
-- CZĘŚĆ 2: PROCEDURA BK_DB - Backup pojedynczej bazy
-- ============================================================================

IF OBJECT_ID('dbo.bk_db', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.bk_db
END
GO

CREATE PROCEDURE dbo.bk_db
    @db NVARCHAR(100),                    -- Nazwa bazy do backup'u
    @path NVARCHAR(200) = N'C:\temp\'     -- Ścieżka do backupu (domyślnie C:\temp\)
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @fname NVARCHAR(1000)
    DECLARE @sql NVARCHAR(MAX)
    DECLARE @timestamp NVARCHAR(50)
    DECLARE @exists INT
    DECLARE @err_msg NVARCHAR(500)
    
    BEGIN TRY
        -- Sprawdzenie czy baza istnieje
        SELECT @exists = COUNT(*) 
        FROM sys.databases 
        WHERE name = @db
        
        IF @exists = 0
        BEGIN
            SET @err_msg = N'Baza ' + @db + N' nie istnieje'
            INSERT INTO BK_LOG (nazwa_b, nazwa_pliku_bk, status, err_msg)
            VALUES (@db, N'N/A', N'FAILED', @err_msg)
            RAISERROR(@err_msg, 16, 1)
        END
        
        -- Formatowanie timestampa: YYYYMMDDHHMM
        SET @timestamp = REPLACE(REPLACE(CONVERT(NVARCHAR(19), GETDATE(), 126), N':', N''), N'-', N'')
        SET @timestamp = SUBSTRING(@timestamp, 1, 12)  -- YYYYMMDDHHMM
        
        -- Dodanie backslasha jeśli brakuje
        IF RIGHT(@path, 1) <> N'\'
            SET @path = @path + N'\'
        
        -- Tworzenie nazwy pliku: NAZWABAZY__YYYYMMDDHHMM.bak
        SET @fname = @path + RTRIM(@db) + N'__' + @timestamp + N'.bak'
        
        -- Budowanie komendy BACKUP DATABASE
        SET @sql = N'BACKUP DATABASE [' + @db + N'] TO DISK = N''' + @fname + N''''
        
        PRINT 'Uruchamianie backup: ' + @fname
        
        -- Wykonanie backup'u
        EXEC sp_executesql @sql
        
        -- Logowanie sukcesu
        INSERT INTO BK_LOG (nazwa_b, nazwa_pliku_bk, status, err_msg)
        VALUES (@db, @fname, N'SUCCESS', NULL)
        
        PRINT 'Backup bazy ' + @db + ' wykonany pomyślnie do: ' + @fname
        
    END TRY
    BEGIN CATCH
        SET @err_msg = ERROR_MESSAGE()
        INSERT INTO BK_LOG (nazwa_b, nazwa_pliku_bk, status, err_msg)
        VALUES (@db, ISNULL(@fname, N'UNKNOWN'), N'FAILED', @err_msg)
        
        PRINT 'BŁĄD podczas backup''u: ' + @err_msg
        RAISERROR(@err_msg, 16, 1)
    END CATCH
END
GO

PRINT 'Procedura bk_db utworzona pomyślnie'
GO

-- ============================================================================
-- CZĘŚĆ 3: PROCEDURA BK_ALL_DB - Backup wszystkich baz
-- ============================================================================

IF OBJECT_ID('dbo.bk_all_db', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.bk_all_db
END
GO

CREATE PROCEDURE dbo.bk_all_db
    @path NVARCHAR(200) = N'C:\temp\'     -- Ścieżka do backupów (domyślnie C:\temp\)
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @db NVARCHAR(100)
    DECLARE @err_msg NVARCHAR(500)
    
    BEGIN TRY
        -- Kursor po wszystkich bazach (pomijając systemowe)
        DECLARE db_cursor CURSOR FOR
            SELECT name 
            FROM sys.databases 
            WHERE name NOT IN ('master', 'model', 'msdb', 'tempdb')
            ORDER BY name
        
        OPEN db_cursor
        FETCH NEXT FROM db_cursor INTO @db
        
        PRINT '========================================='
        PRINT 'Uruchamianie backup wszystkich baz'
        PRINT '========================================='
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            PRINT 'Backup bazy: ' + @db
            
            -- Wywołanie procedury bk_db dla każdej bazy
            BEGIN TRY
                EXEC dbo.bk_db @db = @db, @path = @path
            END TRY
            BEGIN CATCH
                SET @err_msg = ERROR_MESSAGE()
                PRINT 'BŁĄD przy backup''ie bazy ' + @db + ': ' + @err_msg
            END CATCH
            
            FETCH NEXT FROM db_cursor INTO @db
        END
        
        CLOSE db_cursor
        DEALLOCATE db_cursor
        
        PRINT '========================================='
        PRINT 'Backup wszystkich baz ukończony'
        PRINT '========================================='
        
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'db_cursor') >= 0
        BEGIN
            CLOSE db_cursor
            DEALLOCATE db_cursor
        END
        
        SET @err_msg = ERROR_MESSAGE()
        PRINT 'BŁĄD KRYTYCZNY: ' + @err_msg
        RAISERROR(@err_msg, 16, 1)
    END CATCH
END
GO

PRINT 'Procedura bk_all_db utworzona pomyślnie'
GO

-- ============================================================================
-- CZĘŚĆ 4: PROCEDURA BK_GROWTH - Backup baz gdzie przyrosło ponad N rekordów
-- ============================================================================

IF OBJECT_ID('dbo.bk_growth', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.bk_growth
END
GO

CREATE PROCEDURE dbo.bk_growth
    @liczba INT = 5,                      -- Próg przyrostu rekordów (domyślnie 5)
    @path NVARCHAR(200) = N'C:\temp\',    -- Ścieżka do backupów
    @hours_old INT = 12                   -- Porównanie do statystyk starszych niż N godzin
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @db NVARCHAR(100)
    DECLARE @st_id_last INT
    DECLARE @st_id_prev INT
    DECLARE @growth INT
    DECLARE @err_msg NVARCHAR(500)
    DECLARE @sql NVARCHAR(MAX)
    DECLARE @data_last DATETIME
    DECLARE @data_prev DATETIME
    
    BEGIN TRY
        PRINT '========================================='
        PRINT 'Uruchamianie procedury BK_GROWTH'
        PRINT 'Próg przyrostu: ' + CAST(@liczba AS VARCHAR(10)) + ' rekordów'
        PRINT '========================================='
        
        -- Jeśli tabela statystyk nie istnieje - informujemy i wychodzimy
        IF OBJECT_ID('dbo.STAT', 'U') IS NULL
        BEGIN
            PRINT 'UWAGA: Tabela STAT nie istnieje!'
            PRINT 'Procedura wymaga tabeli z statystykami rekordów'
            RETURN
        END
        
        -- Kursor po unikalnych bazach ze statystyk
        DECLARE db_growth_cursor CURSOR FOR
            SELECT DISTINCT db
            FROM dbo.STAT
            ORDER BY db
        
        OPEN db_growth_cursor
        FETCH NEXT FROM db_growth_cursor INTO @db
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            BEGIN TRY
                PRINT ''
                PRINT 'Sprawdzanie bazy: ' + @db
                
                -- Znalezienie ID ostatniej statystyki dla bazy
                SELECT TOP 1 @st_id_last = st_id, @data_last = data_st
                FROM dbo.STAT
                WHERE db = @db
                ORDER BY st_id DESC
                
                IF @st_id_last IS NULL
                BEGIN
                    PRINT '  -> Brak statystyk dla bazy ' + @db
                    FETCH NEXT FROM db_growth_cursor INTO @db
                    CONTINUE
                END
                
                -- Znalezienie ID ostatniej statystyki starszej niż @hours_old godzin
                SELECT TOP 1 @st_id_prev = st_id, @data_prev = data_st
                FROM dbo.STAT
                WHERE db = @db 
                  AND DATEDIFF(HOUR, data_st, GETDATE()) >= @hours_old
                ORDER BY st_id DESC
                
                IF @st_id_prev IS NULL
                BEGIN
                    PRINT '  -> Brak starszych statystyk (ponad ' + CAST(@hours_old AS VARCHAR(10)) + 'h)'
                    FETCH NEXT FROM db_growth_cursor INTO @db
                    CONTINUE
                END
                
                PRINT '  -> Porównanie: st_id_last=' + CAST(@st_id_last AS VARCHAR(10)) 
                    + ' z st_id_prev=' + CAST(@st_id_prev AS VARCHAR(10))
                
                -- Sprawdzenie czy w jakiejkolwiek tabeli był przyrost >= @liczba
                SELECT TOP 1 @growth = (s_now.liczba_rekordow - s_prev.liczba_rekordow)
                FROM dbo.STAT s_now
                JOIN dbo.STAT s_prev 
                    ON s_now.db = s_prev.db 
                    AND s_now.tabla = s_prev.tabla
                WHERE s_now.st_id = @st_id_last
                  AND s_prev.st_id = @st_id_prev
                  AND s_now.db = @db
                  AND (s_now.liczba_rekordow - s_prev.liczba_rekordow) >= @liczba
                ORDER BY (s_now.liczba_rekordow - s_prev.liczba_rekordow) DESC
                
                IF @growth IS NOT NULL AND @growth >= @liczba
                BEGIN
                    PRINT '  -> WYKRYTO PRZYROST: ' + CAST(@growth AS VARCHAR(10)) + ' rekordów!'
                    PRINT '  -> Uruchamianie backup bazy ' + @db
                    
                    -- Wykonanie backup'u
                    EXEC dbo.bk_db @db = @db, @path = @path
                END
                ELSE
                BEGIN
                    PRINT '  -> Brak przyrostu >= ' + CAST(@liczba AS VARCHAR(10)) + ' rekordów'
                END
                
            END TRY
            BEGIN CATCH
                SET @err_msg = ERROR_MESSAGE()
                PRINT '  -> BŁĄD: ' + @err_msg
            END CATCH
            
            FETCH NEXT FROM db_growth_cursor INTO @db
        END
        
        CLOSE db_growth_cursor
        DEALLOCATE db_growth_cursor
        
        PRINT ''
        PRINT '========================================='
        PRINT 'Procedura BK_GROWTH ukończona'
        PRINT '========================================='
        
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'db_growth_cursor') >= 0
        BEGIN
            CLOSE db_growth_cursor
            DEALLOCATE db_growth_cursor
        END
        
        SET @err_msg = ERROR_MESSAGE()
        PRINT 'BŁĄD KRYTYCZNY: ' + @err_msg
        RAISERROR(@err_msg, 16, 1)
    END CATCH
END
GO

PRINT 'Procedura bk_growth utworzona pomyślnie'
GO

-- ============================================================================
-- CZĘŚĆ 5: TESTOWANIE PROCEDUR
-- ============================================================================

PRINT ''
PRINT '========================================='
PRINT 'TESTY PROCEDUR'
PRINT '========================================='

-- Test 1: Backup pojedynczej bazy
PRINT ''
PRINT 'TEST 1: Backup pojedynczej bazy (PM_DB1)'
EXEC dbo.bk_db @db = N'PM_DB1', @path = N'C:\temp\'

-- Test 2: Wyświetlenie logu
PRINT ''
PRINT 'TEST 2: Wyświetlenie dziennika backupów'
SELECT bk_id, nazwa_b, nazwa_pliku_bk, kto, kiedy, status, err_msg
FROM dbo.BK_LOG
ORDER BY bk_id DESC

-- Test 3: Backup wszystkich baz
PRINT ''
PRINT 'TEST 3: Backup wszystkich baz'
-- EXEC dbo.bk_all_db @path = N'C:\temp\'

-- Test 4: Backup baz gdzie przyrosło
PRINT ''
PRINT 'TEST 4: Backup baz gdzie przyrosło > 5 rekordów'
-- EXEC dbo.bk_growth @liczba = 5, @path = N'C:\temp\', @hours_old = 12

PRINT ''
PRINT '========================================='
PRINT 'Koniec testów'
PRINT '========================================='
