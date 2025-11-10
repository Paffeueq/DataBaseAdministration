USE B25_ADM_PM331720
GO

-- Procedura raportujaca bledy podczas odtwarzania kluczy
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
    PRINT 'ERROR REPORT FOR restore_id = ' + CAST(@restore_id AS varchar(10))
    PRINT '========================================='
    PRINT ''
    
    -- 1. FK which already existed
    IF EXISTS (SELECT 1 FROM FK_RESTORE_JOB WHERE package_id = @restore_id AND fk_already_exists = 1)
    BEGIN
        PRINT '--- FK ALREADY EXISTS ---'
        PRINT ''
        
        SELECT 
            fk_name AS 'FK Name',
            detail_table AS 'Details Table',
            detail_col AS 'Details Column',
            master_table AS 'Master Table',
            master_col AS 'Master Column'
        FROM FK_RESTORE_JOB
        WHERE package_id = @restore_id 
            AND fk_already_exists = 1
        ORDER BY detail_table, fk_name
        
        PRINT ''
    END
    
    -- 2. Data inconsistency
    IF EXISTS (SELECT 1 FROM FK_RESTORE_JOB WHERE package_id = @restore_id AND data_inconsistency = 1)
    BEGIN
        PRINT '--- DATA INCONSISTENCY (details below) ---'
        PRINT ''
        
        -- Cursor on jobs with data inconsistency
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
            PRINT '>>> FK: ' + @fk_name
            PRINT '    (' + @detail_table + ' -> ' + @master_table + ')'
            PRINT '    Inconsistent data:'
            PRINT ''
            
            BEGIN TRY
                -- Execute query showing inconsistent data
                EXEC sp_executesql @show_sql
            END TRY
            BEGIN CATCH
                PRINT '    ERROR showing data: ' + ERROR_MESSAGE()
            END CATCH
            
            PRINT ''
            
            FETCH NEXT FROM error_cursor 
                INTO @fk_name, @detail_table, @master_table, @show_sql
        END
        
        CLOSE error_cursor
        DEALLOCATE error_cursor
    END
    
    -- 3. Other errors
    IF EXISTS (SELECT 1 FROM FK_RESTORE_JOB 
               WHERE package_id = @restore_id 
                 AND err_msg IS NOT NULL 
                 AND fk_already_exists = 0 
                 AND data_inconsistency = 0)
    BEGIN
        PRINT '--- OTHER ERRORS ---'
        PRINT ''
        
        SELECT 
            fk_name AS 'FK Name',
            detail_table AS 'Details Table',
            master_table AS 'Master Table',
            err_msg AS 'Error Message'
        FROM FK_RESTORE_JOB
        WHERE package_id = @restore_id 
            AND err_msg IS NOT NULL
            AND fk_already_exists = 0 
            AND data_inconsistency = 0
        ORDER BY detail_table, fk_name
        
        PRINT ''
    END
    
    -- Summary
    DECLARE @total int, @success int, @errors int
    
    SELECT 
        @total = COUNT(*),
        @success = SUM(CASE WHEN cr_end IS NOT NULL AND err_msg IS NULL THEN 1 ELSE 0 END),
        @errors = SUM(CASE WHEN err_msg IS NOT NULL OR fk_already_exists = 1 OR data_inconsistency = 1 THEN 1 ELSE 0 END)
    FROM FK_RESTORE_JOB
    WHERE package_id = @restore_id
    
    PRINT '========================================='
    PRINT 'SUMMARY:'
    PRINT 'Total FK: ' + CAST(@total AS varchar(10))
    PRINT 'Successfully created: ' + CAST(@success AS varchar(10))
    PRINT 'Errors/Skipped: ' + CAST(@errors AS varchar(10))
    PRINT '========================================='
END
GO
