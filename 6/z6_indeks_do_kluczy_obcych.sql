/*
** W większości baz definicja klucza głownego automatycznie tworzy indeks do tej kolumny
** Dlaczego ??
** Unialna waetosc - trzeba szybko sprawdzić czy już takiej nie ma
** Często się szuka po kluczu głownym aby wybrać rekord do edycji
**
** Druga mozliwosc optymalizacji to klucze obce
** Standardowo założenie klucza obcego nie powoduje utworzenia indeksu !!!
**
** KLUCZ OBCY - standard
** 
** Nie pozwala dodać rekordu do tabeli DETAIL ja w nadrzednej MASTER takowy nie istnieje
** OPTYMALNE bo w MASTER jest kucz głowny i szukanie szybkie
** Przyklad - wstawiamy POzFa z ID_FAKTURY = 5 -> Baza sprawdza sprawdza czy faktura z
** ID=5 istnieje. Jest to błyskawiczne ponieważ w tabeli Faktury jest to lucz głowny (ma indeks)
**
** Nie pozwala skasowac jak są rekordy podrzędne
*/

/* Kucz obcy to nie tylko kasowanie
** zakladam ze 99% zapytan ma warunki po kluczu obcym
** Przyklad - edytujemy Fakture, na formularzu pokazujemy dane faktury (szukanie po kluczu gł)
** Oraz jej pozycje -> warunek po kluczu obcym
** SELECT * FROM PozFa WHERE id_faktury = 5
*/
/*
** Zadanie numer 4 (Z4 isOD)
** Napisac procedurę, która ma parametr @NazwaBazy
** Dla podanej bazy wyszukuje wszystkie klucze obce 
**  kolumny w tabeli podrzędnej będące kluczami obcymi
**  przypominam, ze jedno z zadan polegało na zapisaniu kluczy obcych do bazy
** Potrzebujemy nazwę tabeli podrzędnej  i kolumny w tej tabeli będącej kluczem obcym
** Ale tylko takie do których nie ma indeksów (sysindexes)
** Dla nich w pęti (kursor pojedynczo tworzymy)
** Indeksy o nazwie takim jak klucz FKI_TabNadrz__TabPodrz
*/

/* sprawdzenie poprawnosci w sprawozdaniu - ze są potem INDEKSY
** I po 2 uruchomieniach nie powielonych indeksów
** Napisac polecenie SQL z 2 tabel gdzie wymusimy uzycie zrobionego indeksu
** Np. ze wspomnianych PozycjiFaktur gdzie id_faktury ma byc jakieś
*/

-- ============================================================================
-- PROCEDURA Z6_INDEKSY_FK - Tworzenie indeksów dla kluczy obcych
-- ============================================================================

IF OBJECT_ID('dbo.Z6_INDEKSY_FK', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.Z6_INDEKSY_FK
END
GO

CREATE PROCEDURE dbo.Z6_INDEKSY_FK
    @NazwaBazy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON
    
    DECLARE @tabela_podrz NVARCHAR(128)
    DECLARE @kolumna_fk NVARCHAR(128)
    DECLARE @tabela_nadrz NVARCHAR(128)
    DECLARE @nazwa_indeksu NVARCHAR(128)
    DECLARE @sql NVARCHAR(MAX)
    DECLARE @err_msg NVARCHAR(500)
    DECLARE @licznik INT = 0
    
    BEGIN TRY
        -- Sprawdzenie czy baza istnieje
        IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = @NazwaBazy)
        BEGIN
            SET @err_msg = N'Baza danych ' + @NazwaBazy + N' nie istnieje!'
            RAISERROR(@err_msg, 16, 1)
        END
        
        PRINT '========================================='
        PRINT 'Procedura Z6_INDEKSY_FK'
        PRINT 'Baza: ' + @NazwaBazy
        PRINT '========================================='
        PRINT ''
        
        -- Budowanie dynamicznego SQL'a
        SET @sql = N'
        USE [' + @NazwaBazy + N'];
        
        DECLARE @tabela_podrz NVARCHAR(128);
        DECLARE @kolumna_fk NVARCHAR(128);
        DECLARE @tabela_nadrz NVARCHAR(128);
        DECLARE @nazwa_indeksu NVARCHAR(128);
        DECLARE @sql_idx NVARCHAR(MAX);
        DECLARE @err_msg2 NVARCHAR(500);
        DECLARE @licznik2 INT = 0;
        
        DECLARE fk_cursor CURSOR FOR
            SELECT 
                tab_podrz.name AS tabela_podrz,
                col_fk.name AS kolumna_fk,
                tab_nadrz.name AS tabela_nadrz
            FROM sys.foreign_keys fk
            INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
            INNER JOIN sys.tables tab_podrz ON fkc.parent_object_id = tab_podrz.object_id
            INNER JOIN sys.columns col_fk ON fkc.parent_object_id = col_fk.object_id 
                AND fkc.parent_column_id = col_fk.column_id
            INNER JOIN sys.tables tab_nadrz ON fkc.referenced_object_id = tab_nadrz.object_id
            WHERE NOT EXISTS (
                SELECT 1 FROM sys.indexes idx
                WHERE idx.object_id = tab_podrz.object_id
                AND idx.name = ''FKI_'' + tab_nadrz.name + ''__'' + tab_podrz.name
            )
            ORDER BY tab_podrz.name, col_fk.name;
        
        OPEN fk_cursor;
        FETCH NEXT FROM fk_cursor INTO @tabela_podrz, @kolumna_fk, @tabela_nadrz;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            BEGIN TRY
                SET @nazwa_indeksu = N''FKI_'' + @tabela_nadrz + N''__'' + @tabela_podrz;
                
                PRINT ''Tabela podrzędna: '' + @tabela_podrz;
                PRINT ''  Kolumna FK: '' + @kolumna_fk;
                PRINT ''  Tabela nadrzędna: '' + @tabela_nadrz;
                PRINT ''  Nazwa indeksu: '' + @nazwa_indeksu;
                
                SET @sql_idx = N''CREATE INDEX ['' + @nazwa_indeksu + N''] ON [dbo].['' + @tabela_podrz + N''](['' + @kolumna_fk + N''])'';
                
                EXEC sp_executesql @sql_idx;
                
                SET @licznik2 = @licznik2 + 1;
                PRINT ''  ✓ Indeks utworzony!'';
                PRINT '''';
                
            END TRY
            BEGIN CATCH
                SET @err_msg2 = ERROR_MESSAGE();
                PRINT ''  ✗ BŁĄD: '' + @err_msg2;
                PRINT '''';
            END CATCH
            
            FETCH NEXT FROM fk_cursor INTO @tabela_podrz, @kolumna_fk, @tabela_nadrz;
        END
        
        CLOSE fk_cursor;
        DEALLOCATE fk_cursor;
        
        PRINT ''========================================='';
        PRINT ''Procedura Z6_INDEKSY_FK ukończona'';
        PRINT ''Utworzono indeksów: '' + CAST(@licznik2 AS VARCHAR(10));
        PRINT ''========================================='';
        '
        
        -- Wykonanie SQL'a
        EXEC sp_executesql @sql
        
    END TRY
    BEGIN CATCH
        SET @err_msg = ERROR_MESSAGE()
        PRINT 'BŁĄD KRYTYCZNY: ' + @err_msg
        RAISERROR(@err_msg, 16, 1)
    END CATCH
END
GO

PRINT 'Procedura Z6_INDEKSY_FK utworzona pomyślnie'
GO

-- ============================================================================
-- TESTOWANIE - Tworzenie tabel przykładowych
-- ============================================================================

-- Usunięcie tabel jeśli istnieją (do czyszczenia)
IF OBJECT_ID('dbo.PozFa', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.PozFa
END
GO

IF OBJECT_ID('dbo.Faktura', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.Faktura
END
GO

CREATE TABLE Faktura ( id_faktury int not null CONSTRAINT PK_Faktura PRIMARY KEY)
GO

CREATE TABLE PozFa (id_faktury int not null constraint FK_FAKTURA__PozFa FOREIGN kEY REFERENCES Faktura(id_faktury), towar nvarchar(100) not null)
GO

-- Test procedury
PRINT ''
PRINT 'TEST: Uruchomienie procedury dla bieżącej bazy'
DECLARE @db_name NVARCHAR(100) = DB_NAME()
EXEC dbo.Z6_INDEKSY_FK @NazwaBazy = @db_name

-- Sprawdzenie czy indeks został utworzony
PRINT ''
PRINT 'Sprawdzenie indeksów na tabeli PozFa:'
SELECT name, type_desc, is_primary_key
FROM sys.indexes
WHERE object_id = OBJECT_ID('PozFa')
GO

-- Test zapytania z wymuszeniem indeksu
PRINT ''
PRINT 'Test wykorzystania indeksu w zapytaniu:'
SELECT * FROM Faktura f join PozFa p WITH (INDEX(FKI_Faktura__PozFa)) ON (f.id_faktury = p.id_faktury)
 