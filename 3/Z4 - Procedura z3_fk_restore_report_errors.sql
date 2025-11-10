USE B25_ADM_PM331720
GO

-- Procedura raportująca błędy podczas odtwarzania kluczy
IF EXISTS (SELECT 1 FROM sysobjects WHERE name = 'z3_fk_restore_report_errors' AND type = 'P')
    DROP PROCEDURE z3_fk_restore_report_errors
GO

CREATE PROCEDURE z3_fk_restore_report_errors
    @restore_id int
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @show_sql nvarchar(2000)
    DECLARE @fk_name nvarchar(250)
    DECLARE @detail_table nvarchar(100)
    DECLARE @master_table nvarchar(100)
    
    PRINT '========================================='
    PRINT 'RAPORT BŁĘDÓW DLA restore_id = ' + CAST(@restore_id AS varchar(10))
    PRINT '========================================='
    PRINT ''
    
    -- 1. Klucze które już istniały
    IF EXISTS (SELECT 1 FROM FK_RESTORE_JOB WHERE package_id = @restore_id AND fk_already_exists = 1)
    BEGIN
        PRINT '--- KLUCZE KTÓRE JUŻ ISTNIAŁY ---'
        PRINT ''
        
        SELECT 
            fk_name AS 'Nazwa klucza',
            detail_table AS 'Tabela details',
            detail_col AS 'Kolumna details',
            master_table AS 'Tabela master',
            master_col AS 'Kolumna master'
        FROM FK_RESTORE_JOB
        WHERE package_id = @restore_id 
            AND fk_already_exists = 1
        ORDER BY detail_table, fk_name
        
        PRINT ''
    END
    
    -- 2. Niespójne dane
    IF EXISTS (SELECT 1 FROM FK_RESTORE_JOB WHERE package_id = @restore_id AND data_inconsistency = 1)
    BEGIN
        PRINT '--- NIESPÓJNE DANE (szczegóły poniżej) ---'
        PRINT ''
        
        -- Kursor po jobach z niespójnymi danymi
        DECLARE error_cursor CURSOR FOR
            SELECT 
                j.fk_name,
                j.detail_table,
                j.master_table,
                q.s_query_show
            FROM FK_RESTORE_JOB j
            JOIN FK_CHECK_QUERY q 
                ON j.db = q.db
                AND j.master_table = q.tab_to_check
                AND j.master_col = q.col_to_check
                AND j.detail_table = q.tab_where_data_exists
                AND j.detail_col = q.col_name_where_data_exists
            WHERE j.package_id = @restore_id 
                AND j.data_inconsistency = 1
            ORDER BY j.detail_table, j.fk_name
        
        OPEN error_cursor
        FETCH NEXT FROM error_cursor 
            INTO @fk_name, @detail_table, @master_table, @show_sql
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            PRINT '>>> Klucz: ' + @fk_name
            PRINT '    (' + @detail_table + ' -> ' + @master_table + ')'
            PRINT '    Niespójne dane:'
            PRINT ''
            
            BEGIN TRY
                -- Wykonujemy zapytanie pokazujące niespójne dane
                EXEC sp_executesql @show_sql
            END TRY
            BEGIN CATCH
                PRINT '    BŁĄD podczas wyświetlania: ' + ERROR_MESSAGE()
            END CATCH
            
            PRINT ''
            
            FETCH NEXT FROM error_cursor 
                INTO @fk_name, @detail_table, @master_table, @show_sql
        END
        
        CLOSE error_cursor
        DEALLOCATE error_cursor
    END
    
    -- 3. Inne błędy
    IF EXISTS (SELECT 1 FROM FK_RESTORE_JOB 
               WHERE package_id = @restore_id 
                 AND err_msg IS NOT NULL 
                 AND fk_already_exists = 0 
                 AND data_inconsistency = 0)
    BEGIN
        PRINT '--- INNE BŁĘDY ---'
        PRINT ''
        
        SELECT 
            fk_name AS 'Nazwa klucza',
            detail_table AS 'Tabela details',
            master_table AS 'Tabela master',
            err_msg AS 'Komunikat błędu'
        FROM FK_RESTORE_JOB
        WHERE package_id = @restore_id 
            AND err_msg IS NOT NULL
            AND fk_already_exists = 0 
            AND data_inconsistency = 0
        ORDER BY detail_table, fk_name
        
        PRINT ''
    END
    
    -- Podsumowanie
    DECLARE @total int, @success int, @errors int
    
    SELECT 
        @total = COUNT(*),
        @success = SUM(CASE WHEN cr_end IS NOT NULL AND err_msg IS NULL THEN 1 ELSE 0 END),
        @errors = SUM(CASE WHEN err_msg IS NOT NULL OR fk_already_exists = 1 OR data_inconsistency = 1 THEN 1 ELSE 0 END)
    FROM FK_RESTORE_JOB
    WHERE package_id = @restore_id
    
    PRINT '========================================='
    PRINT 'PODSUMOWANIE:'
    PRINT 'Łącznie kluczy: ' + CAST(@total AS varchar(10))
    PRINT 'Utworzonych pomyślnie: ' + CAST(@success AS varchar(10))
    PRINT 'Błędów/pominięć: ' + CAST(@errors AS varchar(10))
    PRINT '========================================='
END
GO

-- Przykład użycia:
-- EXEC z3_fk_restore_report_errors @restore_id = 1