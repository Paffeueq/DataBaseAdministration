/* maciej.stodolski@gmail.com  Administrowanie Bazami Danych Z4 28.10.2025 */

/* Z3
** Opis historyczny
wiele baz danych wymaga załadowania danych inicjalnych
lub ma opcję dodania danych do tabel (wszystkich lub częsci)
Jak baza ma setki tabel to niemozliwe staje sie ustalenie 
do ktorej tabeli najpierw trzeba dane bo inaczej klucze obce odrzuca

dlatego bardzo czesto jest sytuacja gdzie proszą adminow aby
a) usuneli wszystkie klucze obce z bazy
b) laduja dane
c) proszą o odtworzenie kluczy obcych i jak sa bledy o ic przeslanie
(wtedy sprawdzaja co z czym nie gra)

Przykladowo baza z wykladu
Najpierw mozna cos dograc do WOJ potem MIASTA, potem OSOBY, potem FIRMY a na koncu ETATY
jakakolwiek zmiana kolejnosci moze spowodowac ze np
dodamy miasta ktore sa w WOJ ktorego jeszcze nie dogralismy wiec klucz na to nie pozwoli

**
** Stworzymy narzędzia
** 0) Tabele/procedury mają działać dla wszyskich baz na naszym serwerze (bez systemowych)
** Narzędzia mają służyć do (wszystko procedurami SQL zapamiętanymi na bazie adm):
	WSZYSTKIE PROCEDURY MAJA PARAMETR @db -- nazwa bazy dla jakiej mają to zrobić
** z3_fk_store Zapamiętywania stanu bazy
** - kluczy obcych
** z3_fk_rmv Ma być możliwość skasowania wszystkich kluczy obcych za pomocą procedury
**   W zadanie bazie !!!
**   Taka procedure ma najpierw zapamietac w tabeli jakie są klucze
**   a potem je skasowac TYLKO JAK SIE UDA ZAPAMIETAC NAJPIERW KLUCZE
	Czyli 
	a) najpierw zapamietujemy dla danej bazy jakie byly
	a.1) proponuje tabelę - nagłowek gdzie zapisujemy moment rozpoczecia
	a.2) po skasowaniu z sukcesem wszystkich zapisujemy date skonczenia procesu
	a.3) tylko operacje z datą "skonczenia procesu" so brane potem pod uwagę do odtworzenia
	b) usuwamy jak proces a się zakonczył
** z3_fk_restore) Ma być możliwość odtworzenia kluczy obcych procedurą na wybranej bazie
**  odtwarzamy ostatni zapisany stan - który w pełni się udał NA DANEJ BAZIE
**  - procedura szuka ostatniego stanu dla tej bazy (z datą zakonczenia nie NULL) i odtwarza ten stan

	z3_fk_restore_report_errors - raportuje błedy napotkane przy odtwarzaniu

UWAGA - zrobimy tak jak inne zadania:

będzie tabela nagłowek z zapisywaniem lub odtwaraniem, kto, kiedy rozpoczety proces, kiedy zakonczony
oraz związana z nią tabela co ma być zrobione i jak zostało wykonane

dlatego proces odtworzenia kluczy dla danej bazy wyglądałby tak:

a) tworzymy tabele (oczywiście jednorazowo) B25_adm..ZLEC_FK (zlec_fk_id int not null identity constraint PK_ZLEC_FK PRIMARY KEY ...

*/

/*
UWAGA nazwy tabel i kolumn zazwyczaj mogą być do 250 znaków
ale ja chce abyście Państwo zrobili klucz zlozony z dwu nazw tabel, 2 nazw kolumn i nazwy bazy
a calkowita dlugosc klucza nie moze byc wieksza niz 900 - zalezy od SQL 
stąd przyjmujemy max nazwy 100 znakow
*/

use B25_ADM_PM331720
go

/* tabela nadrzedna - nagłowek zapisania kluczy dla danej bazy */
IF NOT EXISTS (select 1 FROM sysobjects o WHERE (o.[name] = N'FK_STORE') and (OBJECTPROPERTY(o.[id], N'IsUserTable')=1))
	CREATE TABLE dbo.FK_STORE
	(	store_id int not null identity constraint PK_FK_STORE PRIMARY KEY
	,	[desc] nvarchar(100) not null
	,	end_dstamp datetime null		-- tylko te z nie pustym end_stamp i pustym err_msg traktujemy jako udane
	,	err_msg nvarchar(250) null
	,	[usr]	nvarchar(100) not null DEFAULT USER_NAME() 
	,	[s_usr]	nvarchar(100) not null DEFAULT SUSER_NAME()
	,	start_dstamp datetime not null DEFAULT GETDATE()
	,	rmv_after_store bit not null
	,	db nvarchar(100) not null
	)
GO
IF NOT EXISTS (select 1 FROM sysobjects o WHERE (o.[name] = N'FK_STORE_DET') and (OBJECTPROPERTY(o.[id], N'IsUserTable')=1))
	CREATE TABLE dbo.FK_STORE_DET
	(	store_id int not null constraint FK_FK_STORE_DET__FK_STORE FOREIGN KEY REFERENCES FK_STORE(store_id)
	,	det_id	int not null Identity constraint PK_FK_STORE_DET PRIMARY KEY
	,	master_tab nvarchar(100) not null -- tabela master
	,	master_col nvarchar(100) not null -- kolumna w tabeli master  przypomne MASTER ---< DETAILS
	,	details_tab nvarchar(100) not null -- tabela details
	,	details_col nvarchar(100) not null -- kolumna w tabeli details
	,	fk_name		nvarchar(250) not null -- nazwa klucza
	,	removed	bit not null default 0
	,	d_stamp datetime not null DEFAULT GETDATE()
	)
GO

/* tabela nadrzedna - opis procesu odtwarzania, data startu i ew zakonczenia jak się wszystko powiodło */
IF NOT EXISTS (select 1 FROM sysobjects o WHERE (o.[name] = N'FK_RESTORE') and (OBJECTPROPERTY(o.[id], N'IsUserTable')=1))
	CREATE TABLE dbo.FK_RESTORE
	(	restore_id int not null identity constraint PK_FK_RESTORE PRIMARY KEY
	,	[desc] nvarchar(100) not null
	,	end_dstamp datetime null
	,	err_msg nvarchar(250) null
	,	db	nvarchar(100) not null
	,	[usr]	nvarchar(100) not null DEFAULT USER_NAME() 
	,	[s_usr]	nvarchar(100) not null DEFAULT SUSER_NAME()
	,	start_dstamp datetime not null DEFAULT GETDATE()
	)

/* tabela z pytaniami sprawdzajacymi reguły integralności
** ALTERNATYWA !!! funkcja zwracająca gotowe zapytanie
*/
-- nie ma tworzymy pustą
if not exists (select 1 from sysobjects o where (o.[name] = N'f_ref_check_query') AND (OBJECTPROPERTY(o.[id], N'IsScalarFunction')=1))
	EXEC sp_sqlExec N'CREATE FUNCTION dbo.F_REF_CHECK_QUERY() returns int AS BEGIN return 0 end'
-- już jest MODYFIKUJEMY
GO
ALTER FUNCTION 
dbo.F_REF_CHECK_QUERY(
		@col_name_where_data_exists nvarchar(100)					-- nazwa kolumny gdzie są dane
	,	@tab_where_data_exists nvarchar(100)						-- nazwa tabeli gdzie jest ta kolumna
	,	@col_to_check nvarchar(100)									-- nazwa kolumny w której będziemy sprawdzać czy są dane
	,	@tab_to_check nvarchar(100)									-- nazwa tabeli w ktorej jest powyzsza kolumna
	,	@db nvarchar(100))											-- nazwa bazy
RETURNS nvarchar(2000)
/*
* dla wywołania 
	select b25_adm.dbo.f_REF_CHECK_Query(N'KOD_WOJ', N'MIASTA', N'KOD_WOJ', N'WOJ', N'PWX_DB')
	powinna funkcja zwrócić
	N'USE PWX_DB;SET @e=0;IF EXISTS(SELECT 1 FROM MIASTA WHERE NOT EXISTS (SELECT 1 FROM WOJ WHERE MIASTA.[KOD_WOJ]=WOJ.[KOD_WOJ])) set @e=1'
 */
BEGIN
	RETURN N'' -- trzeba kod zrobic
END
GO

-- druga blizniacza funkcja niech buduje zapytanie do, które pokaze te brakujące dane
if not exists (select 1 from sysobjects o where (o.[name] = N'f_ref_results') AND (OBJECTPROPERTY(o.[id], N'IsScalarFunction')=1))
	EXEC sp_sqlExec N'CREATE FUNCTION dbo.F_REF_RESULTS() returns int AS BEGIN return 0 end'
-- już jest MODYFIKUJEMY
GO
ALTER FUNCTION 
dbo.F_REF_RESULTS(
		@col_name_where_data_exists nvarchar(100)					-- nazwa kolumny gdzie są dane
	,	@tab_where_data_exists nvarchar(100)						-- nazwa tabeli gdzie jest ta kolumna
	,	@col_to_check nvarchar(100)									-- nazwa kolumny w której będziemy sprawdzać czy są dane
	,	@tab_to_check nvarchar(100)									-- nazwa tabeli w ktorej jest powyzsza kolumna
	,	@db nvarchar(100))											-- nazwa bazy
RETURNS nvarchar(2000)
/*
* dla wywołania 
	select b25_adm.dbo.f_REF_CHECK_Query(N'KOD_WOJ', N'MIASTA', N'KOD_WOJ', N'WOJ', N'PWX_DB')
	powinna funkcja zwrócić
	N'USE PWX_DB;SELECT DISTINCT MIASTA.KOD_WOJ AS [KOD_WOJ w MIASTA nie ma w WOJ] FROM MIASTA WHERE NOT EXISTS (SELECT 1 FROM WOJ WHERE MIASTA.[KOD_WOJ]=WOJ.[KOD_WOJ])'
 */
BEGIN
	RETURN N'' -- trzeba kod zrobic
END
GO

-- testowanie
declare @s2_sql nvarchar(1000)
set @s2_sql = N'USE B25_ADM_PM331720;SELECT DISTINCT MIASTA.KOD_WOJ AS [KOD_WOJ w MIASTA nie ma w WOJ] FROM MIASTA WHERE NOT EXISTS (SELECT 1 FROM WOJ WHERE MIASTA.[KOD_WOJ]=WOJ.[KOD_WOJ])'
exec sp_executeSql @s2_sql
/*
declare @s2_sql nvarchar(1000), @wynik int
set @wynik=6

set @s2_sql = N'USE PWX_DB;set @e=0; '
	+ 'if exists(SELECT DISTINCT MIASTA.KOD_WOJ AS [KOD_WOJ w MIASTA nie ma w WOJ] '
	+ ' FROM MIASTA WHERE NOT EXISTS (SELECT 1 FROM WOJ WHERE MIASTA.[KOD_WOJ]=WOJ.[KOD_WOJ])) set @e=1'
exec sp_executeSql @s2_sql, N'@e int output', @e=@wynik output

select @wynik
*/


/*
KOD_WOJ w MIASTA nie ma w WOJ
-----------------------------

(0 row(s) affected)

ok bo nie ma takich przypadkow, zwracam uwage na tlumaczaco o co chodzi nazwe kolumny
*/

/* tabela w której wszystkie zapytania sprawdzajace będziemy trzymac */
IF NOT EXISTS (select 1 FROM sysobjects o WHERE (o.[name] = N'REF_CHECK_QUERY') and (OBJECTPROPERTY(o.[id], N'IsUserTable')=1))
-- drop table fk_check_query
	CREATE TABLE dbo.FK_CHECK_QUERY
	(	col_name_where_data_exists	nvarchar(100) not null			-- nazwa kolumny gdzie są dane
	,	tab_where_data_exists		nvarchar(100) not null			-- nazwa tabeli gdzie jest ta kolumna
	,	col_to_check				nvarchar(100) not null			-- nazwa kolumny w której będziemy sprawdzać czy są dane
	,	tab_to_check				nvarchar(100) not null			-- nazwa tabeli w ktorej jest powyzsza kolumna
	,	db							nvarchar(100) not null			-- nazwa bazy
	,	s_query_check				nvarchar(2000) not null			-- zapytanie sprawdzajace powyższe f_ref_check_query wynik
	,	s_query_show				nvarchar(2000) not null			-- zapytanie pokazujace zle dane f_ref_results wynik
	,	constraint PK_CHECK_QUERY  PRIMARY KEY (db,tab_to_check,col_to_check,tab_where_data_exists,col_name_where_data_exists)
	)

-- i tabelka ze zleceniami 
IF NOT EXISTS (select 1 FROM sysobjects o WHERE (o.[name] = N'FK_RESTORE_JOB') and (OBJECTPROPERTY(o.[id], N'IsUserTable')=1))
	CREATE TABLE dbo.FK_RESTORE_JOB
	(	job_id						int not null IDENTITY PRIMARY KEY
	,	package_id					int not null CONSTRAINT FK_RESTORE_JOB__RESTORE_FK FOREIGN KEY REFERENCES FK_RESTORE(restore_id)
	,	detail_col					nvarchar(100) not null
	,	detail_table				nvarchar(100) not null
	,	master_col					nvarchar(100) not null
	,	master_table				nvarchar(100) not null
	,	db							nvarchar(100) not null
	,	fk_name						nvarchar(250) NULL -- jak NULL to FK__MASTER__DETAIL
	,	CONSTRAINT FK_RESTORE_JOB__FK_RESTORE FOREIGN KEY (db,master_table,master_col,detail_table,detail_col)
		REFERENCES FK_CHECK_QUERY( db,tab_to_check,col_to_check,tab_where_data_exists,col_name_where_data_exists)
	,	cr_start					datetime NOT NULL DEFAULT(GETDATE())
	,	cr_end						datetime NULL
	,	err_msg						nvarchar(250) NULL -- jak null to OK
	,	fk_already_exists			bit NOT NULL DEFAULT 0 -- 1 jak klucz miedzy takimi tabelami i ich kolumnami w tej bazie jest
	,	data_inconsistency			bit NOT NULL DEFAULT 0 -- 1 jak w detail sa dane których nie ma w master, 
	/* bez bledu jak obydwa powyzsze 0 */
	)
GO

/*
WSKAZÓWKA_0

	declare @obj_size int
	set @obj_size = 20

	SELECT  left(f.name,@obj_size)				AS nazwa_ogr
		,	left(OBJECT_NAME(f.parent_object_id) ,@obj_size)
								AS details_tab
		,	left(COL_NAME(fc.parent_object_id, fc.parent_column_id) , @obj_size)
								AS details_col
		,	left(OBJECT_NAME (f.referenced_object_id) , @obj_size)
								AS master_tab
		,	left(COL_NAME(fc.referenced_object_id, fc.referenced_column_id) ,@obj_size)
								AS master_col
		FROM sys.foreign_keys AS f
		JOIN sys.foreign_key_columns AS fc
		ON f.[object_id] = fc.constraint_object_id
		ORDER BY f.name

	*/

/* 
WSKAZÓWKA Z3.1

-- usuwanie klucza
ALTER TABLE NazwaTabeli DROP CONSTRAINT NazwaOgr

PROCEDURA USUWANIA KLUCZY NAJPIERW POWINNA JE ZAPAMIETAC W TABELACH !!!
np u mnie:

alter table firmy drop constraint fk_firmy__miasta

WSKAZÓWKA Z3.2

-- dodawanie kluczy do tabeli
USE baza;
ALTER TABLE dbo.nazwa_tabeli ADD CONSTRAINT nazwa_klucza FOREIGN KEY (kolumna) REFERENCES MasterTabela(kolumna_w_master)

Przykładowo:
EXEC dbo.DB_FK_RESTORE  @db='pwx_db'
generuje i wykonuje ponisze polecenia (przykładowo tylko dla ETATY):
USE [pwx_db];  ALTER TABLE etaty ADD CONSTRAINT FK_ETATY_ETATY FOREIGN KEY (z_etatu) REFERENCES etaty(id_etatu)
USE [pwx_db];  ALTER TABLE etaty ADD CONSTRAINT fk_etaty__osoby FOREIGN KEY (id_osoby) REFERENCES osoby(id_osoby)
USE [pwx_db];  ALTER TABLE etaty ADD CONSTRAINT fk_etaty__firmy FOREIGN KEY (id_firmy) REFERENCES firmy(nazwa_skr)
USE [pwx_db];  ALTER TABLE firmy ADD CONSTRAINT fk_firmy__miasta FOREIGN KEY (id_miasta) REFERENCES miasta(id_miasta)

*/

/* objaśnienie do wykonania procedur
*/

/*
** z3_fk_store (@db nvarchar(100), @store_id int=null output ) Zapamiętywania stanu bazy

1. Wstawiamy rekord do tabeli FK_STORE
2. Pobieramy id jakie zostało nadane - przez SCOPE_IDENTITY() : @store_id = SCOPE_IDENTITY()
3. robimy zapytanie ze wskazówka_0 dla danej bazy
-- ja bym zbudował napis z tym zapytaniem dodając USE nazwaB; na początku a wynik skierował do tabeliFK_STORE_DET
-- i uzyl exec sp_executeSql do wykonania
-- pola z rmv na 0
-- na potrzeby kolejnego zadania przekazywałbym nadane id (ze wstawienia do FK_STORE) poprzez parametr typu OUTPUT


** z3_fk_rmv (@db nvarchar(100) )

1. skorzystałbym z procedury z3_fk_store ale wyołałbym tak aby uzyskac z powrotem parametr dostepu do FK_STORE
	exec z3_fk_store(@db=@db, @store_id=@store_id output)

2. dla tak zwróconej danej zrobiłbym kursor po wierszach z FK_STORE_DET (potrzeba bedzie det_id, nazwa_klucza, nazwa_tabeli_detail
	aby zgodnie ze wskazówką_1 skasować klucz 'USE nazwaBazy;ALTER TABLE NazwaTabeliDetail DROP CONSTRAINT NazwaKlucza'
3. Po skasowaniu (mozna sprawdzic zm  globalną @@ERROR) zaznaczamy w FK_STORE_DET ze skasowalismy, dlatego potrzebowalismy det_id


z3_fk_restore (@db nvarchar(100) )
**  odtwarzamy ostatni zapisany stan - który w pełni się udał NA DANEJ BAZIE
**  - procedura szuka ostatniego stanu dla tej bazy (z datą zakonczenia nie NULL) i odtwarza ten stan
1. szukamy id który się udał dla danej bazy -- store_id
2. budujemy nowy rekord w tabeli FK_RESTORE
3. zapamietujemy jego restore_id
4. robimy kursor z danym z tabeli FK_RESTORE_DET
5. dla pojedynczego wiersza:
	5.1 sprawdzamy czy istnieje juz SQL w tabeli FK_CHECK_QUERY dla tych tabel i tych kolumn
		nie - wstawiamy nowy rekord uzywajac do budowy zapytan wczesniej opisanych funkcji
	5.2 pobieramy z FK_CHECK_QUERY zapytania i sprawdzamy czy są spełnione warunki
	5.3 sprawdzamy czy istnieje juz klucz pomiedzy tymi tabelami z tymi kolumnami (bez warunku na nazwe klucza)
	5.4 wstawiamy nowy wiersz do tabeli FK_RESTORE_JOB z odpowiednimi flagami zapalonymi przez punkty 5.2 i 5.3
	5.5 jak obie flagi na 0 to budujemy polecenie utworzenia klucza
	5.6 uruchamiamy polecenie utworzenia klucza tylko jak nie ma i dane spójne

6. na koncu sprawdzamy czy byly bledy jak byly to uruchamiamy procedure z3_fk_restore_report_errors


z3_fk_restore_report_errors(@restore_id int) - raportuje błedy napotkane przy odtwarzaniu
1. najpierw zapytanie pokazujące klucze które już były a kazaliśmy je utworzyć
2. potem kursor po FK_RESTORE_DET (dla danego @restore_id) ale takich gdzie @data_inconsistency jest 1
	i tam uruchamiamy sql z kolumny FK_CHECK_QUERY.s_query_show
	Tabele FK_CHECK_QUERY i FK_RESTORE_DET połączone są kluczem obcym stąd w kursorze można od razu połaczyć je i wybierać
	wspomniane zapytanie a potem w pętli uruchamiać


TESTOWANIE:

ze 2 bazy w których mamy dane w WOJ/MIASTA/OSOBY/FIRMY/ETATY

a. we wszystkich bazach zapamietujemy klucze z3_fk_store (procedura lub sam kursor po wszystkich bazach - bez systemowych)
b. dla wspomnianych 2 baz kasujemy klucze

dla a i b pokazujemy zawartość tabel systemowych

dla jednej z baz dodajemy kilka rekordów ale miasto o takim kod_woj którego nie ma w tabeli woj
etat dla takiej firmy której nie ma w tabeli firmy

uruchamiamy odtwarzanie kluczy
raportujemy błedy
udowadniamy ze klucze są (zapytaniem ze wskazówki 0) w tej bazie gdzie bledów nie bylo 
a tylko część jest w tej bazie gdzie były błedy
 
 */
