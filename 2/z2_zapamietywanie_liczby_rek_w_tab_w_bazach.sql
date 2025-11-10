/*
Nazwa pliku sprawozdania Z2_nrAlbumu.[txt | sql | PDF]
Sprawozdanie zaczynamy od:
Imię Nazwisko, NumerAlbumu, dzień zajęć

Z2 Administracja BD

logowanie do sieci:
login: numerALbumu
hasło: numerAlbumu

logowanie do SQL w laboratorium (do kazdego SQL indywidualnie na kazdej stacji stąd z zewnątrz 
nie da się

program MS Management SQL studio (w lab wersja 2012)
host (musi być nazwa komputera typu P# gdzie # to numer komputera BEZ NICZEGO WIECEJ)
user: sa (małe litery)
hasło: Zima@2022
*/


/* proszę stworzyć skrypt w którym
1. Korzystając ze skryptu z Z1 proszę utworzyć minimum 5 baz
2. W 3ech z nich proszę utworzyć tabele i dane z wykładu z BAZ (WOJ,MIASTA,OSOBY,ETATY)
i wypełnić wartościami, jak nie mają Państwo swojego skryptu to w chmurze jest mój w
katalogu zaczynającym się od Z2...  stud_zal_baza.sql
3. Proszę w jednej z baz dodać kilka rekordów więcej do ETATY i OSOBY (według uznania)
4. Zadaniem jest śledzenie liczby rekordów w tabelach w bazach
4.1 Proszę utworzyć tabele:
*/

USE B25_ADM
GO

IF NOT EXISTS (SELECT 1 FROM sysobjects o WHERE o.[name] = N'DB_CHECK'
	AND (OBJECTPROPERTY(o.[ID], N'IsUserTable')=1)
)
CREATE TABLE B25_ADM.dbo.DB_CHECK
( check_id int not null IDENTITY CONSTRAINT PK_DB_CHECK PRIMARY KEY
, db_nam nvarchar(50) not null -- w jakiej bazie
, d_stamp datetime NOT NULL DEFAULT GETDATE() -- o której godzinie
, opis nvarchar(50) NOT NULL
, [usr] nvarchar(50) NOT NULL DEFAULT USER_NAME()
, [s_usr] nvarchar(50) NOT NULL DEFAULT SUSER_NAME()
)
IF NOT EXISTS (SELECT 1 FROM sysobjects o WHERE o.[name] = N'DB_CHECK_ITEMS'
	AND (OBJECTPROPERTY(o.[ID], N'IsUserTable')=1)
)
CREATE TABLE B25_ADM.dbo.DB_CHECK_ITEMS
( check_id int not null CONSTRAINT FK_DB_CHECK__DB_CHECK_ITEMS FOREIGN KEY
	REFERENCES B25_ADM.dbo.DB_CHECK (check_id)
, tb_nam nvarchar(50) not null -- nazwa tabeli w bazie
, liczba_reordow int not null
, tb_check_d_stamp datetime NOT NULL DEFAULT GETDATE() -- o której godzinie dodano rekord
)

/*
** 4.2 Trzeba utworzyć procedurę, która ma kursor po wszystkich bazach
(za wyjątkiem administracyjnych !!! tak jak w Z1)
Trzeba utworzyć procedurę, która dla podanej bazy wylistuje wszystkie tabele
wstawi rekord do tabeli B25_ADM.dbo.DB_CHECK i z tak uzyskanym identyfikatorem
wstawi dla kazdej tabeli aktualną liczbę rekordów do tabeli
B25_ADM.dbo.DB_CHECK_ITEMS

DECLARE @i int
INSERT INTO B25_ADM.dbo.DB_CHECK(opis,db_nam) VALUES (N'Procedura XX',N'EEFT')
SET @i = SCOPE_IDENTITY()

DECLARE @sql nvarchar(2000), @d nvarchar(50)
CREATE TABLE #t (t_name nvarchar(50) NOT NULL)

SET @d = N'EEFT' -- nazwa bazy ma byc parametrem procedury
SET @sql = N'USE ' + @d 
	+ N';INSERT INTO #t (t_name) '
	+ N' SELECT o.[name] FROM ' + @d + '..sysobjects o WHERE OBJECTPROPERTY(o.[ID],N''IsUserTable'')=1'
EXEC sp_SqlExec @sql

-- kursor z tabeli #t
-- inny sposob to kursor z tabeli sysobjects od razu
SELECT *  FROM #t

W pętli np:
SET @sql = 'USE ' + @d + N';INSERT INTO B25_ADM.dbo.DB_CHECK_ITEMS(check_id,tb_nam,liczba_rekordow) + SELECT '
   + STR(@i 10, 0) + N',''' + @tb + ''', COUNT(*) FROM ' + @tb 
  STR - z liczby na ile znakow i ile po kropce


teraz trzeba zrobić kursor po #t i dla kazdej z tabel policzyc liczbę rekordów
i tę liczbę zapisać w tabeli B25_ADM.dbo.DB_CHECK_ITEMS

4.3 Napisać procedurę, która dla wszystkich baz 
(za wyjątkiem baz systemowych - tak jak w Z1)
wywoła procedurę z punktu 4.2

DECLARE @d NVARCHAR(50)
CREATE CI INSENSITIVE CURSOR FOR
	SELECT d.[name] FROM master..sysdatabases d
		WHERE d.name not in (N'master',N'tempdb', N'model', N'msdb', N'B25_ADM')
		ORDER BY 1

OPEN CI 
FETCH NEXT FROM CI INTO @d
WHILE @@FETCH_STATUS = 0
BEGIN
	SELECT @d AS db_name
	EXEC proc_42 @db = @d
	FETCH NEXT FROM CI INTO @d
END
CLOSE CI
DEALLOCATE CI

4.4 Napisać procedurę, która dla parametru nazwa bazy, 
nazwa tabeli wypisze historię 
liczby rekordów dla podanej tabeli w podanej bazie
 
4.5 Statystyki

Napisać procedurę do której przekazemy 
check_id_1 i check_id_2
Procedura musi sprawdzić czy to są poprawne identyfikatory tabeli B25_ADM.dbo.DB_CHECK
a) Jak któryś nie istnieje w tabeli to RAISERROR('Check_id nie istniej w B25_ADM.dbo.DB_CHECK', 16, 3)
i koniec procedury

b) Procedura ta zwróci tabelę
baza, tabela, liczba_reordow_dla_check_1, liczba_reordow_dla_check_2
, przyrost liczony jako liczba_reordow_dla_check_2 - liczba_reordow_dla_check_1

c) Procedura w MS-SQL może zwracaćwiele wyników. Nasz ma jeszcze wyszukać maksymalny przyrost
czyli ma zwrócić:
baza, tabela, najwiekszy_przyrost_w_bazie_pomiedzy_check1_i_check2

4.5.1
Procedurę z 4.5.1 wykorzystać do analizy 
- przyrostów miesięcznych
wtedy parametrem jest miesiąc jako N'202510'  (convert(nchar(6), @jakas_data_lub_kol_datetime,112)
create procedure b25.dbo.ST_M @parametr_ym nchar(6), @baza nvarchar(100)

jako check_id_2 wyszukujemy 
SELECT MAX(c.check_id) FROM B25_ADM.dbo.DB_CHECK c 
WHERE convert(nchar(6), c.d_stamp,112) = @parametr_ym AND c.db_nam = @baza
czyli max z miesiąca
a check_id_1
SELECT MIN(c.check_id) FROM B25_ADM.dbo.DB_CHECK c 
WHERE convert(nchar(6), c.d_stamp,112) = @parametr_ym  AND c.db_nam = @baza
czyli min z miesiąca

dla tak uzyskanych check_id_1 i check_id_2 wywołujemy procedurę z 4.5

4.5.2
Tak samo jak 4.5.1 ale statystyka dla dnia
create procedure b25.dbo.ST_M @parametr_dzien nchar(8), @baza nvarchar(100) 

jako check_id_2 wyszukujemy 
SELECT MAX(c.check_id) FROM B25_ADM.dbo.DB_CHECK c 
WHERE convert(nchar(8), c.d_stamp,112) = @parametr_dz  AND c.db_nam = @baza
czyli max z dnia

... tak samo jak 4.5.1 - analogicznie

*/
