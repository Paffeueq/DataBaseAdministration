USE B25_ADM_PM331720
GO

/*
========================================
SKRYPT CZYSZCZĄCY DANE TESTOWE
========================================
Użyj tego skryptu jeśli chcesz wyczyścić 
dane testowe i rozpocząć testy od nowa
*/

PRINT '========================================='
PRINT 'CZYSZCZENIE DANYCH TESTOWYCH'
PRINT '========================================='
PRINT ''

-- Usuń dane z tabel w odpowiedniej kolejności (klucze obce)
PRINT 'Usuwam dane z FK_RESTORE_JOB...'
DELETE FROM FK_RESTORE_JOB
PRINT 'Usunięto ' + CAST(@@ROWCOUNT AS varchar(10)) + ' wierszy'
PRINT ''

PRINT 'Usuwam dane z FK_CHECK_QUERY...'
DELETE FROM FK_CHECK_QUERY
PRINT 'Usunięto ' + CAST(@@ROWCOUNT AS varchar(10)) + ' wierszy'
PRINT ''

PRINT 'Usuwam dane z FK_RESTORE...'
DELETE FROM FK_RESTORE
PRINT 'Usunięto ' + CAST(@@ROWCOUNT AS varchar(10)) + ' wierszy'
PRINT ''

PRINT 'Usuwam dane z FK_STORE_DET...'
DELETE FROM FK_STORE_DET
PRINT 'Usunięto ' + CAST(@@ROWCOUNT AS varchar(10)) + ' wierszy'
PRINT ''

PRINT 'Usuwam dane z FK_STORE...'
DELETE FROM FK_STORE
PRINT 'Usunięto ' + CAST(@@ROWCOUNT AS varchar(10)) + ' wierszy'
PRINT ''

-- Reset identity jeśli chcesz zacząć od ID = 1
PRINT 'Resetuję liczniki IDENTITY...'
DBCC CHECKIDENT ('FK_STORE', RESEED, 0)
DBCC CHECKIDENT ('FK_STORE_DET', RESEED, 0)
DBCC CHECKIDENT ('FK_RESTORE', RESEED, 0)
DBCC CHECKIDENT ('FK_RESTORE_JOB', RESEED, 0)
PRINT ''

PRINT '========================================='
PRINT 'CZYSZCZENIE ZAKOŃCZONE'
PRINT '========================================='
PRINT ''

-- Pokaż stan tabel
PRINT 'Stan tabel po czyszczeniu:'
SELECT 'FK_STORE' AS Tabela, COUNT(*) AS [Liczba wierszy] FROM FK_STORE
UNION ALL
SELECT 'FK_STORE_DET', COUNT(*) FROM FK_STORE_DET
UNION ALL
SELECT 'FK_RESTORE', COUNT(*) FROM FK_RESTORE
UNION ALL
SELECT 'FK_RESTORE_JOB', COUNT(*) FROM FK_RESTORE_JOB
UNION ALL
SELECT 'FK_CHECK_QUERY', COUNT(*) FROM FK_CHECK_QUERY