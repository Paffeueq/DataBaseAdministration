USE B25_ADM_PM331720
GO

/* 
========================================
SKRYPT TESTOWY DLA ZADANIA Z4
========================================
*/

PRINT '========================================='
PRINT 'TEST 1: Zapamiętanie kluczy obcych'
PRINT '========================================='
PRINT ''

-- a) Zapamiętujemy klucze dla wszystkich baz (przykład dla PWX_DB)
DECLARE @store_id1 int
EXEC z3_fk_store @db = 'PWX_DB', @store_id = @store_id1 OUTPUT
PRINT 'Utworzono store_id: ' + CAST(@store_id1 AS varchar(10))
PRINT ''

-- Pokazujemy co zapisaliśmy
PRINT 'Zawartość FK_STORE:'
SELECT store_id, [desc], db, start_dstamp, end_dstamp, err_msg 
FROM FK_STORE 
WHERE store_id = @store_id1

PRINT ''
PRINT 'Zawartość FK_STORE_DET:'
SELECT store_id, master_tab, master_col, details_tab, details_col, fk_name, removed
FROM FK_STORE_DET 
WHERE store_id = @store_id1
ORDER BY det_id

PRINT ''
PRINT '========================================='
PRINT 'TEST 2: Sprawdzenie istniejących kluczy przed usunięciem'
PRINT '========================================='
PRINT ''

-- Pokazujemy klucze obce w bazie PWX_DB
DECLARE @sql_check nvarchar(max)
SET @sql_check = N'USE PWX_DB;
SELECT  
    f.name AS nazwa_klucza,
    OBJECT_NAME(f.parent_object_id) AS tabela_details,
    COL_NAME(fc.parent_object_id, fc.parent_column_id) AS kolumna_details,
    OBJECT_NAME(f.referenced_object_id) AS tabela_master,
    COL_NAME(fc.referenced_object_id, fc.referenced_column_id) AS kolumna_master
FROM sys.foreign_keys AS f
JOIN sys.foreign_key_columns AS fc ON f.[object_id] = fc.constraint_object_id
ORDER BY f.name'

PRINT 'Klucze obce w bazie PWX_DB PRZED usunięciem:'
EXEC sp_executesql @sql_check
PRINT ''

PRINT '========================================='
PRINT 'TEST 3: Usunięcie kluczy obcych'
PRINT '========================================='
PRINT ''

-- b) Kasujemy klucze z bazy PWX_DB
EXEC z3_fk_rmv @db = 'PWX_DB'
PRINT ''

-- Sprawdzamy czy klucze zostały usunięte
PRINT 'Klucze obce w bazie PWX_DB PO usunięciu:'
EXEC sp_executesql @sql_check
PRINT ''

-- Pokazujemy, które klucze zostały oznaczone jako usunięte
PRINT 'Status usunięcia w FK_STORE_DET:'
SELECT 
    master_tab, master_col, details_tab, details_col, fk_name, 
    removed, 
    CASE WHEN removed = 1 THEN 'USUNIĘTY' ELSE 'NIE USUNIĘTY' END AS status
FROM FK_STORE_DET 
WHERE store_id = @store_id1
ORDER BY det_id
PRINT ''

PRINT '========================================='
PRINT 'TEST 4: Dodanie niespójnych danych'
PRINT '========================================='
PRINT ''

-- Dodajemy miasto z nieistniejącym kodem województwa
PRINT 'Dodaję miasto z nieistniejącym KOD_WOJ...'
DECLARE @sql_insert nvarchar(max)
SET @sql_insert = N'USE PWX_DB;
INSERT INTO MIASTA (ID_MIASTA, KOD_WOJ, NAZWA)
VALUES (9999, ''XX'', ''Miasto testowe - złe dane'')'

BEGIN TRY
    EXEC sp_executesql @sql_insert
    PRINT 'Dodano miasto z nieistniejącym KOD_WOJ = ''XX'''
END TRY
BEGIN CATCH
    PRINT 'UWAGA: Nie można dodać - prawdopodobnie są inne ograniczenia'
END CATCH

-- Dodajemy etat dla nieistniejącej firmy
PRINT 'Dodaję etat dla nieistniejącej firmy...'
SET @sql_insert = N'USE PWX_DB;
INSERT INTO ETATY (ID_ETATU, ID_OSOBY, ID_FIRMY, PENSJA, DATA_OD)
VALUES (9999, 1, ''FAKE_FIRMA'', 5000, GETDATE())'

BEGIN TRY
    EXEC sp_executesql @sql_insert
    PRINT 'Dodano etat z nieistniejącą firmą = ''FAKE_FIRMA'''
END TRY
BEGIN CATCH
    PRINT 'UWAGA: Nie można dodać - ' + ERROR_MESSAGE()
END CATCH

PRINT ''
PRINT '========================================='
PRINT 'TEST 5: Odtworzenie kluczy obcych'
PRINT '========================================='
PRINT ''

-- Odtwarzamy klucze
EXEC z3_fk_restore @db = 'PWX_DB'
PRINT ''

PRINT '========================================='
PRINT 'TEST 6: Sprawdzenie odtworzonych kluczy'
PRINT '========================================='
PRINT ''

-- Sprawdzamy które klucze zostały odtworzone
PRINT 'Klucze obce w bazie PWX_DB PO odtworzeniu:'
EXEC sp_executesql @sql_check
PRINT ''

PRINT '========================================='
PRINT 'TEST 7: Analiza rezultatów odtwarzania'
PRINT '========================================='
PRINT ''

-- Pobieramy ostatni restore_id
DECLARE @last_restore_id int
SELECT TOP 1 @last_restore_id = restore_id 
FROM FK_RESTORE 
ORDER BY start_dstamp DESC

PRINT 'Zawartość FK_RESTORE:'
SELECT restore_id, [desc], db, start_dstamp, end_dstamp, err_msg
FROM FK_RESTORE
WHERE restore_id = @last_restore_id

PRINT ''
PRINT 'Zawartość FK_RESTORE_JOB:'
SELECT 
    job_id,
    fk_name,
    detail_table,
    master_table,
    fk_already_exists,
    data_inconsistency,
    CASE 
        WHEN cr_end IS NOT NULL THEN 'UTWORZONY'
        WHEN err_msg IS NOT NULL THEN 'BŁĄD: ' + err_msg
        ELSE 'POMINIĘTY'
    END AS status
FROM FK_RESTORE_JOB
WHERE package_id = @last_restore_id
ORDER BY job_id

PRINT ''
PRINT '========================================='
PRINT 'KONIEC TESTÓW'
PRINT '========================================='