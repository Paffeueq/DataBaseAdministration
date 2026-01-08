-- ============================================================================
-- TESTY PROCEDURY Z6_INDEKSY_FK
-- ============================================================================

PRINT ''
PRINT '========================================='
PRINT 'TEST 0: URUCHOMIENIE PROCEDURY'
PRINT '========================================='
DECLARE @db_name NVARCHAR(100) = DB_NAME()
EXEC dbo.Z6_INDEKSY_FK @NazwaBazy = @db_name
GO

PRINT ''
PRINT '========================================='
PRINT 'TEST 1: Sprawdzenie czy indeks został utworzony'
PRINT '========================================='
SELECT name, type_desc, is_primary_key
FROM sys.indexes
WHERE object_id = OBJECT_ID('PozFa')
ORDER BY name
GO

PRINT ''
PRINT '========================================='
PRINT 'TEST 2: Wszystkie indeksy zawierające FKI'
PRINT '========================================='
SELECT 
    t.name AS tabela,
    i.name AS indeks,
    i.type_desc AS typ,
    c.name AS kolumna
FROM sys.indexes i
INNER JOIN sys.tables t ON i.object_id = t.object_id
INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE i.name LIKE 'FKI_%'
ORDER BY t.name, i.name
GO

PRINT ''
PRINT '========================================='
PRINT 'TEST 3: Wstawienie danych testowych'
PRINT '========================================='
INSERT INTO Faktura (id_faktury) VALUES (1)
INSERT INTO Faktura (id_faktury) VALUES (2)
INSERT INTO Faktura (id_faktury) VALUES (3)
GO

INSERT INTO PozFa (id_faktury, towar) VALUES (1, 'Laptop')
INSERT INTO PozFa (id_faktury, towar) VALUES (1, 'Mysz')
INSERT INTO PozFa (id_faktury, towar) VALUES (2, 'Monitor')
INSERT INTO PozFa (id_faktury, towar) VALUES (3, 'Klawiatura')
GO

PRINT 'Dane wstawione!'
GO

PRINT ''
PRINT '========================================='
PRINT 'TEST 4: Zapytanie z wymuszonym indeksem'
PRINT '========================================='
SELECT 
    f.id_faktury,
    p.towar,
    'Użyto indeksu FKI_Faktura__PozFa' AS metoda
FROM Faktura f 
JOIN PozFa p WITH (INDEX(FKI_Faktura__PozFa)) ON (f.id_faktury = p.id_faktury)
ORDER BY f.id_faktury, p.towar
GO

PRINT ''
PRINT '========================================='
PRINT 'WSZYSTKIE TESTY ZAKOŃCZONE!'
PRINT '========================================='