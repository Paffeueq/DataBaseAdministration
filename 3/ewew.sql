-- Sprawdź czy wszystkie obiekty zostały utworzone
USE B25_ADM_PM331720
GO

SELECT 'Tabele' AS Typ, name AS Nazwa 
FROM sysobjects 
WHERE type = 'U' AND name LIKE 'FK_%'

UNION ALL

SELECT 'Funkcje', name 
FROM sysobjects 
WHERE type IN ('FN', 'TF') AND name LIKE 'F_REF_%'

UNION ALL

SELECT 'Procedury', name 
FROM sysobjects 
WHERE type = 'P' AND name LIKE 'z3_fk_%'