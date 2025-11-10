USE B25_ADM_PM331720
GO

-- Funkcja budująca zapytanie sprawdzające integralność referencyjną
ALTER FUNCTION dbo.F_REF_CHECK_QUERY(
    @col_name_where_data_exists nvarchar(100),  -- kolumna w tabeli master (gdzie powinny być dane)
    @tab_where_data_exists nvarchar(100),        -- tabela master
    @col_to_check nvarchar(100),                 -- kolumna w tabeli details (którą sprawdzamy)
    @tab_to_check nvarchar(100),                 -- tabela details
    @db nvarchar(100))                           -- nazwa bazy
RETURNS nvarchar(2000)
/*
 * Przykład wywołania:
 * SELECT b25_adm.dbo.f_REF_CHECK_QUERY(N'KOD_WOJ', N'WOJ', N'KOD_WOJ', N'MIASTA', N'PWX_DB')
 * Zwraca:
 * N'USE PWX_DB;SET @e=0;IF EXISTS(SELECT 1 FROM MIASTA WHERE NOT EXISTS (SELECT 1 FROM WOJ WHERE MIASTA.[KOD_WOJ]=WOJ.[KOD_WOJ])) SET @e=1'
 */
BEGIN
    DECLARE @result nvarchar(2000)
    
    SET @result = N'USE ' + QUOTENAME(@db) + N';SET @e=0;IF EXISTS(SELECT 1 FROM ' 
        + QUOTENAME(@tab_to_check) + N' WHERE NOT EXISTS (SELECT 1 FROM ' 
        + QUOTENAME(@tab_where_data_exists) + N' WHERE ' 
        + QUOTENAME(@tab_to_check) + N'.' + QUOTENAME(@col_to_check) + N'='
        + QUOTENAME(@tab_where_data_exists) + N'.' + QUOTENAME(@col_name_where_data_exists) 
        + N')) SET @e=1'
    
    RETURN @result
END
GO

-- Funkcja budująca zapytanie pokazujące niespójne dane
ALTER FUNCTION dbo.F_REF_RESULTS(
    @col_name_where_data_exists nvarchar(100),  -- kolumna w tabeli master
    @tab_where_data_exists nvarchar(100),        -- tabela master
    @col_to_check nvarchar(100),                 -- kolumna w tabeli details
    @tab_to_check nvarchar(100),                 -- tabela details
    @db nvarchar(100))                           -- nazwa bazy
RETURNS nvarchar(2000)
/*
 * Przykład wywołania:
 * SELECT b25_adm.dbo.f_REF_RESULTS(N'KOD_WOJ', N'WOJ', N'KOD_WOJ', N'MIASTA', N'PWX_DB')
 * Zwraca:
 * N'USE PWX_DB;SELECT DISTINCT MIASTA.KOD_WOJ AS [KOD_WOJ w MIASTA nie ma w WOJ] FROM MIASTA WHERE NOT EXISTS (SELECT 1 FROM WOJ WHERE MIASTA.[KOD_WOJ]=WOJ.[KOD_WOJ])'
 */
BEGIN
    DECLARE @result nvarchar(2000)
    DECLARE @col_alias nvarchar(300)
    
    SET @col_alias = @col_to_check + N' w ' + @tab_to_check + N' nie ma w ' + @tab_where_data_exists
    
    SET @result = N'USE ' + QUOTENAME(@db) + N';SELECT DISTINCT ' 
        + QUOTENAME(@tab_to_check) + N'.' + QUOTENAME(@col_to_check) 
        + N' AS ' + QUOTENAME(@col_alias)
        + N' FROM ' + QUOTENAME(@tab_to_check) 
        + N' WHERE NOT EXISTS (SELECT 1 FROM ' 
        + QUOTENAME(@tab_where_data_exists) + N' WHERE ' 
        + QUOTENAME(@tab_to_check) + N'.' + QUOTENAME(@col_to_check) + N'='
        + QUOTENAME(@tab_where_data_exists) + N'.' + QUOTENAME(@col_name_where_data_exists) 
        + N')'
    
    RETURN @result
END
GO

-- Test funkcji
PRINT 'Test F_REF_CHECK_QUERY:'
SELECT dbo.F_REF_CHECK_QUERY(N'KOD_WOJ', N'WOJ', N'KOD_WOJ', N'MIASTA', N'PWX_DB') AS CheckQuery
PRINT ''
PRINT 'Test F_REF_RESULTS:'
SELECT dbo.F_REF_RESULTS(N'KOD_WOJ', N'WOJ', N'KOD_WOJ', N'MIASTA', N'PWX_DB') AS ResultsQuery