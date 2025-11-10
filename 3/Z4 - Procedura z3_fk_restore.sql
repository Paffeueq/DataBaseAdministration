USE B25_ADM_PM331720
GO

-- Procedura odtwarzająca klucze obce
IF EXISTS (SELECT 1 FROM sysobjects WHERE name = 'z3_fk_restore' AND type = 'P')
    DROP PROCEDURE z3_fk_restore
GO

CREATE PROCEDURE z3_fk_restore
    @db nvarchar(100)
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @store_id int
    DECLARE @restore_id int
    DECLARE @master_tab nvarchar(100)
    DECLARE @master_col nvarchar(100)
    DECLARE @details_tab nvarchar(100)
    DECLARE @details_col nvarchar(100)
    DECLARE @fk_name nvarchar(250)
    DECLARE @sql nvarchar(max)
    DECLARE @check_sql nvarchar(2000)
    DECLARE @show_sql nvarchar(2000)
    DECLARE @err int
    DECLARE @data_inconsistency bit
    DECLARE @fk_already_exists bit
    DECLARE @job_id int
    DECLARE @err_msg nvarchar(250)
    
    BEGIN TRY
        -- 1. Szukamy ostatniego udanego store dla tej bazy
        SELECT TOP 1 @store_id = store_id
        FROM FK_STORE
        WHERE db = @db 
            AND end_dstamp IS NOT NULL 
            AND err_msg IS NULL
        ORDER BY end_dstamp DESC
        
        IF @store_id IS NULL
        BEGIN
            PRINT 'Brak zapisanego stanu kluczy obcych dla bazy ' + @db
            RETURN
        END
        
        PRINT 'Znaleziono store_id=' + CAST(@store_id AS varchar(10)) + ' dla bazy ' + @db
        
        -- 2. Tworzymy rekord w FK_RESTORE
        INSERT INTO FK_RESTORE ([desc], db)
        VALUES ('Odtwarzanie kluczy dla bazy ' + @db, @db)
        
        SET @restore_id = SCOPE_IDENTITY()
        PRINT 'Utworzono restore_id=' + CAST(@restore_id AS varchar(10))
        
        -- 4. Kursor po kluczach do odtworzenia
        DECLARE restore_cursor CURSOR FOR
            SELECT master_tab, master_col, details_tab, details_col, fk_name
            FROM FK_STORE_DET
            WHERE store_id = @store_id
            ORDER BY det_id
        
        OPEN restore_cursor
        FETCH NEXT FROM restore_cursor 
            INTO @master_tab, @master_col, @details_tab, @details_col, @fk_name
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            BEGIN TRY
                SET @data_inconsistency = 0
                SET @fk_already_exists = 0
                SET @err_msg = NULL
                
                -- 5.1 Sprawdzamy czy istnieje zapytanie w FK_CHECK_QUERY
                IF NOT EXISTS (
                    SELECT 1 FROM FK_CHECK_QUERY
                    WHERE db = @db
                        AND tab_to_check = @master_tab
                        AND col_to_check = @master_col
                        AND tab_where_data_exists = @details_tab
                        AND col_name_where_data_exists = @details_col
                )
                BEGIN
                    -- Generujemy zapytania
                    SET @check_sql = dbo.F_REF_CHECK_QUERY(@details_col, @details_tab, @master_col, @master_tab, @db)
                    SET @show_sql = dbo.F_REF_RESULTS(@details_col, @details_tab, @master_col, @master_tab, @db)
                    
                    -- Wstawiamy do FK_CHECK_QUERY
                    INSERT INTO FK_CHECK_QUERY 
                        (col_name_where_data_exists, tab_where_data_exists, col_to_check, tab_to_check, db, s_query_check, s_query_show)
                    VALUES 
                        (@details_col, @details_tab, @master_col, @master_tab, @db, @check_sql, @show_sql)
                END
                ELSE
                BEGIN
                    -- Pobieramy istniejące zapytania
                    SELECT @check_sql = s_query_check, @show_sql = s_query_show
                    FROM FK_CHECK_QUERY
                    WHERE db = @db
                        AND tab_to_check = @master_tab
                        AND col_to_check = @master_col
                        AND tab_where_data_exists = @details_tab
                        AND col_name_where_data_exists = @details_col
                END
                
                -- 5.2 Sprawdzamy spójność danych
                DECLARE @data_err int = 0
                EXEC sp_executesql @check_sql, N'@e int OUTPUT', @e = @data_err OUTPUT
                
                IF @data_err = 1
                    SET @data_inconsistency = 1
                
                -- 5.3 Sprawdzamy czy klucz już istnieje
                SET @sql = N'USE ' + QUOTENAME(@db) + N';
                SELECT @exists = COUNT(*)
                FROM sys.foreign_keys AS f
                JOIN sys.foreign_key_columns AS fc ON f.[object_id] = fc.constraint_object_id
                WHERE OBJECT_NAME(f.parent_object_id) = @det_tab
                    AND COL_NAME(fc.parent_object_id, fc.parent_column_id) = @det_col
                    AND OBJECT_NAME(f.referenced_object_id) = @mst_tab
                    AND COL_NAME(fc.referenced_object_id, fc.referenced_column_id) = @mst_col'
                
                DECLARE @exists int = 0
                EXEC sp_executesql @sql, 
                    N'@det_tab nvarchar(100), @det_col nvarchar(100), @mst_tab nvarchar(100), @mst_col nvarchar(100), @exists int OUTPUT',
                    @det_tab = @details_tab, @det_col = @details_col, @mst_tab = @master_tab, @mst_col = @master_col, @exists = @exists OUTPUT
                
                IF @exists > 0
                    SET @fk_already_exists = 1
                
                -- 5.4 Wstawiamy job do FK_RESTORE_JOB
                INSERT INTO FK_RESTORE_JOB 
                    (package_id, detail_col, detail_table, master_col, master_table, db, fk_name, 
                     fk_already_exists, data_inconsistency)
                VALUES 
                    (@restore_id, @details_col, @details_tab, @master_col, @master_tab, @db, @fk_name,
                     @fk_already_exists, @data_inconsistency)
                
                SET @job_id = SCOPE_IDENTITY()
                
                -- 5.5 i 5.6 Tworzymy klucz tylko jak nie ma problemów
                IF @fk_already_exists = 0 AND @data_inconsistency = 0
                BEGIN
                    SET @sql = N'USE ' + QUOTENAME(@db) + N'; ALTER TABLE ' 
                        + QUOTENAME(@details_tab) + N' ADD CONSTRAINT ' 
                        + QUOTENAME(@fk_name) + N' FOREIGN KEY (' + QUOTENAME(@details_col) + N') '
                        + N'REFERENCES ' + QUOTENAME(@master_tab) + N'(' + QUOTENAME(@master_col) + N')'
                    
                    EXEC sp_executesql @sql
                    
                    -- Oznaczamy jako zakończone
                    UPDATE FK_RESTORE_JOB
                    SET cr_end = GETDATE()
                    WHERE job_id = @job_id
                    
                    PRINT 'Utworzono klucz: ' + @fk_name
                END
                ELSE
                BEGIN
                    IF @fk_already_exists = 1
                        SET @err_msg = 'Klucz już istnieje'
                    IF @data_inconsistency = 1
                        SET @err_msg = ISNULL(@err_msg + '; ', '') + 'Niespójne dane'
                    
                    UPDATE FK_RESTORE_JOB
                    SET err_msg = @err_msg
                    WHERE job_id = @job_id
                    
                    PRINT 'Pominięto klucz ' + @fk_name + ': ' + @err_msg
                END
                
            END TRY
            BEGIN CATCH
                SET @err_msg = ERROR_MESSAGE()
                
                UPDATE FK_RESTORE_JOB
                SET err_msg = @err_msg
                WHERE job_id = @job_id
                
                PRINT 'BŁĄD przy tworzeniu klucza ' + @fk_name + ': ' + @err_msg
            END CATCH
            
            FETCH NEXT FROM restore_cursor 
                INTO @master_tab, @master_col, @details_tab, @details_col, @fk_name
        END
        
        CLOSE restore_cursor
        DEALLOCATE restore_cursor
        
        -- Sprawdzamy czy były błędy
        IF EXISTS (SELECT 1 FROM FK_RESTORE_JOB WHERE package_id = @restore_id AND (err_msg IS NOT NULL OR fk_already_exists = 1 OR data_inconsistency = 1))
        BEGIN
            PRINT 'Wykryto błędy - uruchamiam raport...'
            EXEC z3_fk_restore_report_errors @restore_id = @restore_id
        END
        ELSE
        BEGIN
            -- Wszystko OK
            UPDATE FK_RESTORE
            SET end_dstamp = GETDATE()
            WHERE restore_id = @restore_id
            
            PRINT 'Zakończono pomyślnie odtwarzanie kluczy'
        END
        
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'restore_cursor') >= 0
        BEGIN
            CLOSE restore_cursor
            DEALLOCATE restore_cursor
        END
        
        SET @err_msg = ERROR_MESSAGE()
        
        UPDATE FK_RESTORE
        SET err_msg = @err_msg
        WHERE restore_id = @restore_id
        
        PRINT 'BŁĄD KRYTYCZNY: ' + @err_msg
        THROW
    END CATCH
END
GO