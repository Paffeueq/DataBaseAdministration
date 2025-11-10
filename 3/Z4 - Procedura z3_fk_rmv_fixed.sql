USE B25_ADM_PM331720
GO

-- Procedura usuwajaca klucze obce z danej bazy
IF EXISTS (SELECT 1 FROM sysobjects WHERE name = 'z3_fk_rmv' AND type = 'P')
    DROP PROCEDURE z3_fk_rmv
GO

CREATE PROCEDURE z3_fk_rmv
    @db nvarchar(100)
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @store_id int
    DECLARE @det_id int
    DECLARE @fk_name nvarchar(250)
    DECLARE @details_tab nvarchar(100)
    DECLARE @sql nvarchar(max)
    DECLARE @err int
    DECLARE @err_msg nvarchar(250)
    
    BEGIN TRY
        -- 1. Najpierw zapamiętujemy klucze
        EXEC z3_fk_store @db = @db, @store_id = @store_id OUTPUT
        
        PRINT 'Starting FK removal for database ' + @db + ' (store_id=' + CAST(@store_id AS varchar(10)) + ')'
        
        -- 2. Tworzymy kursor po zapisanych kluczach
        DECLARE fk_cursor CURSOR FOR
            SELECT det_id, fk_name, details_tab
            FROM FK_STORE_DET
            WHERE store_id = @store_id
            ORDER BY det_id
        
        OPEN fk_cursor
        FETCH NEXT FROM fk_cursor INTO @det_id, @fk_name, @details_tab
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            BEGIN TRY
                -- 3. Budujemy polecenie usunięcia klucza
                SET @sql = N'USE ' + QUOTENAME(@db) + N'; ALTER TABLE ' 
                    + QUOTENAME(@details_tab) + N' DROP CONSTRAINT ' 
                    + QUOTENAME(@fk_name)
                
                -- Wykonujemy usunięcie
                EXEC sp_executesql @sql
                
                -- Sprawdzamy błędy
                SET @err = @@ERROR
                
                IF @err = 0
                BEGIN
                    -- Oznaczamy jako usunięty
                    UPDATE FK_STORE_DET
                    SET removed = 1
                    WHERE det_id = @det_id
                    
                    PRINT 'Removed FK: ' + @fk_name + ' from table ' + @details_tab
                END
                
            END TRY
            BEGIN CATCH
                SET @err_msg = ERROR_MESSAGE()
                PRINT 'ERROR removing FK ' + @fk_name + ': ' + @err_msg
            END CATCH
            
            FETCH NEXT FROM fk_cursor INTO @det_id, @fk_name, @details_tab
        END
        
        CLOSE fk_cursor
        DEALLOCATE fk_cursor
        
        PRINT 'Finished FK removal for database ' + @db
        
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'fk_cursor') >= 0
        BEGIN
            CLOSE fk_cursor
            DEALLOCATE fk_cursor
        END
        
        SET @err_msg = ERROR_MESSAGE()
        PRINT 'CRITICAL ERROR: ' + @err_msg
    END CATCH
END
GO
