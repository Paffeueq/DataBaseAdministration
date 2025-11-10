USE B25_ADM_PM331720
GO

-- Procedura zapamiętująca klucze obce z danej bazy
IF EXISTS (SELECT 1 FROM sysobjects WHERE name = 'z3_fk_store' AND type = 'P')
    DROP PROCEDURE z3_fk_store
GO

CREATE PROCEDURE z3_fk_store
    @db nvarchar(100),
    @store_id int = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @sql nvarchar(max)
    DECLARE @err_msg nvarchar(250)
    
    BEGIN TRY
        -- 1. Wstawiamy rekord do tabeli FK_STORE
        INSERT INTO FK_STORE ([desc], db, rmv_after_store)
        VALUES ('Zapamiętanie kluczy obcych dla bazy ' + @db, @db, 0)
        
        -- 2. Pobieramy nadane id
        SET @store_id = SCOPE_IDENTITY()
        
        -- 3. Budujemy zapytanie do pobrania kluczy obcych z danej bazy
        SET @sql = N'USE ' + QUOTENAME(@db) + N';
        INSERT INTO b25_adm.dbo.FK_STORE_DET 
            (store_id, master_tab, master_col, details_tab, details_col, fk_name, removed)
        SELECT  
            ' + CAST(@store_id AS nvarchar(20)) + N' AS store_id,
            OBJECT_NAME(f.referenced_object_id) AS master_tab,
            COL_NAME(fc.referenced_object_id, fc.referenced_column_id) AS master_col,
            OBJECT_NAME(f.parent_object_id) AS details_tab,
            COL_NAME(fc.parent_object_id, fc.parent_column_id) AS details_col,
            f.name AS fk_name,
            0 AS removed
        FROM sys.foreign_keys AS f
        JOIN sys.foreign_key_columns AS fc
            ON f.[object_id] = fc.constraint_object_id
        ORDER BY f.name'
        
        -- Wykonujemy zapytanie
        EXEC sp_executesql @sql
        
        -- Jeśli wszystko OK, ustawiamy datę zakończenia
        UPDATE FK_STORE 
        SET end_dstamp = GETDATE()
        WHERE store_id = @store_id
        
        PRINT 'Zapamiętano klucze obce dla bazy ' + @db + ' (store_id=' + CAST(@store_id AS varchar(10)) + ')'
        
    END TRY
    BEGIN CATCH
        SET @err_msg = ERROR_MESSAGE()
        
        -- Zapisujemy błąd
        UPDATE FK_STORE 
        SET err_msg = @err_msg
        WHERE store_id = @store_id
        
        PRINT 'BŁĄD podczas zapamiętywania kluczy: ' + @err_msg
        
        -- Rzucamy błąd dalej
        THROW 50001, 'Error in z3_fk_store procedure', 1
    END CATCH
END
GO

-- Test procedury
DECLARE @test_store_id int
EXEC z3_fk_store @db = 'PWX_DB', @store_id = @test_store_id OUTPUT
SELECT @test_store_id AS 'Utworzony store_id'

-- Sprawdzenie rezultatu
SELECT * FROM FK_STORE WHERE store_id = @test_store_id
SELECT * FROM FK_STORE_DET WHERE store_id = @test_store_id