USE B25_ADM_PM331720
GO

/* 
========================================
TEST SCRIPT FOR TASK Z4
========================================
*/

PRINT '========================================='
PRINT 'TEST 1: Save foreign keys'
PRINT '========================================='
PRINT ''

-- a) Save FK for all databases (example for PWX_DB)
DECLARE @store_id1 int
EXEC z3_fk_store @db = 'PWX_DB', @store_id = @store_id1 OUTPUT
PRINT 'Created store_id: ' + CAST(@store_id1 AS varchar(10))
PRINT ''

-- Show what we saved
PRINT 'Content of FK_STORE:'
SELECT store_id, [desc], db, start_dstamp, end_dstamp, err_msg 
FROM FK_STORE 
WHERE store_id = @store_id1

PRINT ''
PRINT 'Content of FK_STORE_DET:'
SELECT store_id, master_tab, master_col, details_tab, details_col, fk_name, removed
FROM FK_STORE_DET 
WHERE store_id = @store_id1
ORDER BY det_id

PRINT ''
PRINT '========================================='
PRINT 'TEST 2: Check existing keys before removal'
PRINT '========================================='
PRINT ''

-- Show FK in PWX_DB
DECLARE @sql_check nvarchar(max)
SET @sql_check = N'USE PWX_DB;
SELECT  
    f.name AS FK_Name,
    OBJECT_NAME(f.parent_object_id) AS Details_Table,
    COL_NAME(fc.parent_object_id, fc.parent_column_id) AS Details_Column,
    OBJECT_NAME(f.referenced_object_id) AS Master_Table,
    COL_NAME(fc.referenced_object_id, fc.referenced_column_id) AS Master_Column
FROM sys.foreign_keys AS f
JOIN sys.foreign_key_columns AS fc ON f.[object_id] = fc.constraint_object_id
ORDER BY f.name'

PRINT 'Foreign keys in PWX_DB BEFORE removal:'
EXEC sp_executesql @sql_check
PRINT ''

PRINT '========================================='
PRINT 'TEST 3: Remove foreign keys'
PRINT '========================================='
PRINT ''

-- b) Remove FK from PWX_DB
EXEC z3_fk_rmv @db = 'PWX_DB'
PRINT ''

-- Check if FK were removed
PRINT 'Foreign keys in PWX_DB AFTER removal:'
EXEC sp_executesql @sql_check
PRINT ''

-- Show which FK were marked as removed
PRINT 'Removal status in FK_STORE_DET:'
SELECT 
    master_tab, master_col, details_tab, details_col, fk_name, 
    removed, 
    CASE WHEN removed = 1 THEN 'REMOVED' ELSE 'NOT REMOVED' END AS status
FROM FK_STORE_DET 
WHERE store_id = @store_id1
ORDER BY det_id
PRINT ''

PRINT '========================================='
PRINT 'TEST 4: Add inconsistent data'
PRINT '========================================='
PRINT ''

-- Add city with non-existing province code
PRINT 'Adding city with non-existing KOD_WOJ...'
DECLARE @sql_insert nvarchar(max)
SET @sql_insert = N'USE PWX_DB;
INSERT INTO MIASTA (ID_MIASTA, KOD_WOJ, NAZWA)
VALUES (9999, ''XX'', ''Test city - bad data'')'

BEGIN TRY
    EXEC sp_executesql @sql_insert
    PRINT 'Added city with non-existing KOD_WOJ = ''XX'''
END TRY
BEGIN CATCH
    PRINT 'WARNING: Cannot add - other constraints may exist'
END CATCH

-- Add employment for non-existing company
PRINT 'Adding employment for non-existing company...'
SET @sql_insert = N'USE PWX_DB;
INSERT INTO ETATY (ID_ETATU, ID_OSOBY, ID_FIRMY, PENSJA, DATA_OD)
VALUES (9999, 1, ''FAKE_FIRMA'', 5000, GETDATE())'

BEGIN TRY
    EXEC sp_executesql @sql_insert
    PRINT 'Added employment with non-existing company = ''FAKE_FIRMA'''
END TRY
BEGIN CATCH
    PRINT 'WARNING: Cannot add - ' + ERROR_MESSAGE()
END CATCH

PRINT ''
PRINT '========================================='
PRINT 'TEST 5: Restore foreign keys'
PRINT '========================================='
PRINT ''

-- Restore FK
EXEC z3_fk_restore @db = 'PWX_DB'
PRINT ''

PRINT '========================================='
PRINT 'TEST 6: Check restored keys'
PRINT '========================================='
PRINT ''

-- Check which FK were restored
PRINT 'Foreign keys in PWX_DB AFTER restoration:'
EXEC sp_executesql @sql_check
PRINT ''

PRINT '========================================='
PRINT 'TEST 7: Analyze restoration results'
PRINT '========================================='
PRINT ''

-- Get last restore_id
DECLARE @last_restore_id int
SELECT TOP 1 @last_restore_id = restore_id 
FROM FK_RESTORE 
ORDER BY start_dstamp DESC

PRINT 'Content of FK_RESTORE:'
SELECT restore_id, [desc], db, start_dstamp, end_dstamp, err_msg
FROM FK_RESTORE
WHERE restore_id = @last_restore_id

PRINT ''
PRINT 'Content of FK_RESTORE_JOB:'
SELECT 
    job_id,
    fk_name,
    detail_table,
    master_table,
    fk_already_exists,
    data_inconsistency,
    CASE 
        WHEN cr_end IS NOT NULL THEN 'CREATED'
        WHEN err_msg IS NOT NULL THEN 'ERROR: ' + err_msg
        ELSE 'SKIPPED'
    END AS status
FROM FK_RESTORE_JOB
WHERE package_id = @last_restore_id
ORDER BY job_id

PRINT ''
PRINT '========================================='
PRINT 'END OF TESTS'
PRINT '========================================='
