/*
Za³o¿enie bazy pwx_db i uzytkownika pwx_db z haslem pwx_db

*/

	create database pwx_db
go
	use pwx_db
go
	EXEC sp_addlogin @loginame='pwx_db',@passwd='pwx_db',@defdb=pwx_db
	EXEC sp_adduser @loginame='pwx_db'
	EXEC sp_addrolemember @rolename = 'db_owner',@membername='pwx_db' 
go

IF EXISTS
( SELECT 1
	FROM sysobjects o
	WHERE	(o.[name] = 'pr_rmv_table')
	AND	(OBJECTPROPERTY(o.[ID],'IsProcedure')=1)
)
BEGIN
	DROP PROCEDURE pr_rmv_table
		
END

GO

CREATE PROCEDURE [dbo].pr_rmv_table
(	@table_name nvarchar(100)
)
AS
/* Procedura sprawdza czy istnieje w bazie tabela @table_name
** Jak tak to usuwa j¹
*/
	DECLARE @stmt nvarchar(1000)

	IF EXISTS 
	( SELECT 1
		FROM sysobjects o
		WHERE	(o.[name] = @table_name)
		AND	(OBJECTPROPERTY(o.[ID],'IsUserTable')=1)
	)
	BEGIN
		SET @stmt = 'DROP TABLE ' + @table_name
		EXECUTE sp_executeSQL @stmt = @stmt
	END
GO

/* Usuniêcie tabel w kolejnosci odwrotnej do ich zalo¿enia */

EXEC pr_rmv_table @table_name='firmy_cechy'
EXEC pr_rmv_table @table_name='wartosci_cech'
EXEC pr_rmv_table @table_name='cechy'


EXEC pr_rmv_table @table_name='etat'
EXEC pr_rmv_table @table_name='etaty'
EXEC pr_rmv_table @table_name='osoby'
EXEC pr_rmv_table @table_name='osoba'
EXEC pr_rmv_table @table_name='firmy'
EXEC pr_rmv_table @table_name='firma'
EXEC pr_rmv_table @table_name='miasta'
EXEC pr_rmv_table @table_name='miasto'
EXEC pr_rmv_table @table_name='woj'
EXEC pr_rmv_table @table_name='wojewodztwo'

GO

/*******************
* Definicja Tabel
********************
*/

create table [dbo].woj 
(	kod_woj 	char(3) 	not null 	
	constraint pk_woj primary key
,	nazwa 		varchar(30) 	not null
)

insert into woj values ('Maz', 'Mazowieckie')
insert into woj values ('Pom', 'Pomorskie')
insert into woj values ('???', '<Nieznane>')

GO

DECLARE @id_wwa int
,	@id_wes int
,	@id_gda int
,	@id_sop	int
,	@id_ms	int
,	@id_jk	int
,	@id_jn	int
,	@id_kn	int
,	@id_br1 int
,	@id_br	int
,	@id_am	int


create table [dbo].miasta 
(	id_miasta 	int 		not null identity 
	constraint pk_miasta primary key
,	kod_woj 	char(3) 	not null 
	constraint fk_miasta__woj foreign key 
	references woj(kod_woj)
,	nazwa 		varchar(30) 	not null
)

insert into miasta (kod_woj, nazwa) values ('MAZ', 'WESO£A')
SET @id_wes = SCOPE_IDENTITY()
insert into miasta (kod_woj, nazwa) values ('MAZ', 'WARSZAWA')
SET @id_wwa = SCOPE_IDENTITY()
insert into miasta (kod_woj, nazwa) values ('POM', 'GDAÑSK')
SET @id_gda = SCOPE_IDENTITY()
insert into miasta (kod_woj, nazwa) values ('POM', 'SOPOT')
SET @id_sop = SCOPE_IDENTITY()

create table [dbo].osoby 
(	id_osoby	int 		not null identity
	constraint pk_osoby primary key
,	id_miasta	int 		not null
	constraint fk_osoby__miasta foreign key
	references miasta(id_miasta)
,	imiê		varchar(20) 	not null
,	nazwisko	varchar(30) 	not null
,	imiê_i_nazwisko as convert(char(24),left(imiê,1)+'. ' + nazwisko)
)


create table [dbo].firmy 
(	nazwa_skr	char(3) 	not null
	constraint pk_firmy primary key
,	id_miasta	int 		not null
	constraint fk_firmy__miasta foreign key
	references miasta(id_miasta)
,	nazwa		varchar(60) 	not null
,	kod_pocztowy	char(6)		not null
,	ulica		varchar(60)	not null
)

insert into osoby (imiê, nazwisko, id_miasta) values ('Maciej', 'Stodolski', @id_wes)
SET @id_ms = SCOPE_IDENTITY()

insert into osoby (imiê, nazwisko, id_miasta) values ('Jacek', 'Korytkowski', @id_wwa)
SET @id_jk = SCOPE_IDENTITY()

insert into osoby (imiê, nazwisko, id_miasta) values ('Mis', 'Nieznany', @id_gda)

insert into osoby (imiê, nazwisko, id_miasta) values ('Król', 'Neptun', @id_sop)
set @id_kn = SCOPE_IDENTITY()

insert into osoby (imiê, nazwisko, id_miasta) values ('Ju¿', 'Niepracuj¹cy', @id_wwa)
SET @id_jn = SCOPE_IDENTITY()


insert into [dbo].firmy 
(	nazwa_skr
,	nazwa
,	id_miasta
,	kod_pocztowy
,	ulica
) values 
(	'HP'
, 	'Hewlett Packard'
,	@id_wwa
,	'00-000'
,	'Szturmowa 2a'
)

insert into firmy 
(	nazwa_skr
,	nazwa
,	id_miasta
,	kod_pocztowy
,	ulica
) values 
(	'PW'
,	'Politechnika Warszawska'
,	@id_wwa
,	'00-000'
,	'Pl. Politechniki 1'
)

insert into firmy 
(	nazwa_skr
,	nazwa
,	id_miasta
,	kod_pocztowy
,	ulica
) values 
(	'F£P'
,	'Fabryka £odzi Podwodnych'
,	@id_wwa
,	'00-000'
,	'Na dnie 4'
)


create table [dbo].etaty 
(	id_osoby 	int 		not null 
	constraint fk_etaty__osoby 
	foreign key references osoby(id_osoby)
,	id_firmy 	char(3) 	not null 
	constraint fk_etaty__firmy 
	foreign key references firmy(nazwa_skr)
,	stanowisko	varchar(60)	not null
,	pensja 		money 		not null
,	od 		datetime 	not null
,	do 		datetime 	null
,	id_etatu 	int 		not null identity 
	constraint pk_etaty primary key
)

insert into etaty 
(	id_osoby
,	id_firmy
,	pensja
,	od
,	do
,	stanowisko
) values 
(	@id_ms
,	'PW'
,	600
,	convert(datetime,'19940101',112)
,	convert(datetime,'19980101',112)
,	'Doktorant'
)

insert into etaty 
(	id_osoby
,	id_firmy
,	pensja
,	od
,	do
,	stanowisko
) values 
(	@id_ms
,	'PW'
,	1600
,	convert(datetime,'19980102',112)
,	convert(datetime,'20000101',112)
,	'Asystent'
)

insert into etaty 
(	id_osoby
,	id_firmy
,	pensja
,	od
,	stanowisko
) values 
(	@id_ms
,	'PW'
,	3200
,	convert(datetime,'20000102',112)
,	'Adjunkt'
)

insert into etaty 
(	id_osoby
,	id_firmy
,	pensja
,	od
,	stanowisko
) values 
(	@id_ms
,	'PW'
,	2200
,	convert(datetime,'19990101',112)
,	'Sprz¹tacz'
)

insert into etaty 
(	id_osoby
,	id_firmy
,	pensja
,	od
,	stanowisko
) values 
(	@id_ms
,	'HP'
,	20000
,	convert(datetime,'20000101',112)
,	'Konsultant'
)

insert into etaty 
(	id_osoby
,	id_firmy
,	pensja
,	od
,	stanowisko
) values 
(	@id_jk
,	'PW'
,	3200
,	convert(datetime,'20011110',112)
,	'Adjunkt'
)


insert into etaty 
(	id_osoby
,	id_firmy
,	pensja
,	od
,	stanowisko
,	do
) values 
(	@id_ms
,	'PW'
,	4200
,	convert(datetime,'20040922',112)
,	'Magazynier'
,	convert(datetime,'20041022',112)
)

insert into etaty 
(	id_osoby
,	id_firmy
,	pensja
,	od
,	stanowisko
,	do
) values 
(	@id_jn
,	'HP'
,	50000
,	convert(datetime,'20000101',112)
,	'Dyrektor'
,	convert(datetime,'20021021',112)
)

insert into etaty 
(	id_osoby
,	id_firmy
,	pensja
,	od
,	stanowisko
,	do
) values 
(	@id_ms
,	'F£P'
,	6200
,	convert(datetime,'20040922',112)
,	'Kierownik'
,	convert(datetime,'20041022',112)
)

insert into etaty 
(	id_osoby
,	id_firmy
,	pensja
,	od
,	stanowisko
) values 
(	@id_kn
,	'F£P'
,	65200
,	convert(datetime,'20041023',112)
,	'Prezes'
)



CREATE TABLE [dbo].CECHY
(	id_CECHY	int 		NOT NULL IDENTITY
	CONSTRAINT PK_CECHY PRIMARY KEY
,	Opis_cechy	varchar(60)	NOT NULL
,	jednowybieralna	bit		NOT NULL	DEFAULT 0
)

CREATE TABLE [dbo].WARTOSCI_CECH
(	id_wartosci	int		NOT NULL	IDENTITY
	CONSTRAINT PK_WARTOSCI_CECH PRIMARY KEY
,	id_CECHY	int 		NOT NULL
	CONSTRAINT FK_WARTOSCI_CECHY__CECHY FOREIGN KEY 
	REFERENCES CECHY(ID_CECHY)
,	Opis_wartosci	varchar(40)	NOT NULL
)

CREATE TABLE [dbo].FIRMY_CECHY
(	id_wartosci	int		NOT NULL
	CONSTRAINT FK_FIRMY_CECHY__WARTOSCI_CECH FOREIGN KEY 
	REFERENCES WARTOSCI_CECH(ID_WARTOSCI)
,	id_firmy	char(3)		NOT NULL
,	CONSTRAINT PK_FIRMY_CECHY PRIMARY KEY (id_wartosci,id_firmy)
)

INSERT INTO CECHY (opis_cechy) VALUES ('Bran¿a')
SET @id_br = SCOPE_IDENTITY()

INSERT INTO CECHY (opis_cechy,jednowybieralna) VALUES ('Odpowiedz na Akcjê Marketingow¹ - WIOSNA NASZA',1)
SET @id_am = SCOPE_IDENTITY()

INSERT INTO wartosci_cech
(	id_cechy
,	opis_wartosci
) VALUES
(	@id_br
,	'Komputery'
)
SET @id_br1 = SCOPE_IDENTITY()
INSERT INTO FIRMY_CECHY (id_wartosci,id_firmy) VALUES (@id_br1,'HP')

INSERT INTO wartosci_cech
(	id_cechy
,	opis_wartosci
) VALUES
(	@id_br
,	'Drukarki'
)
SET @id_br1 = SCOPE_IDENTITY()
INSERT INTO FIRMY_CECHY (id_firmy,id_wartosci) VALUES ('HP', @id_br1)

INSERT INTO wartosci_cech
(	id_cechy
,	opis_wartosci
) VALUES
(	@id_br
,	'Szkolenia'
)
SET @id_br1 = SCOPE_IDENTITY()
INSERT INTO FIRMY_CECHY (id_firmy,id_wartosci) VALUES ('HP', @id_br1)
INSERT INTO FIRMY_CECHY (id_firmy,id_wartosci) VALUES ('PW', @id_br1)

INSERT INTO wartosci_cech
(	id_cechy
,	opis_wartosci
) VALUES
(	@id_am
,	'NIE'
)
INSERT INTO wartosci_cech
(	id_cechy
,	opis_wartosci
) VALUES
(	@id_am
,	'TAK'
)
SET @id_br1 = SCOPE_IDENTITY()
INSERT INTO FIRMY_CECHY (id_firmy,id_wartosci) VALUES ('HP', @id_br1)
INSERT INTO FIRMY_CECHY (id_firmy,id_wartosci) VALUES ('F£P', @id_br1)

go

/*
** Pokaz firmy, które maj¹ wartosci cech: 'Komputery i Akcja Marketingowa TAK
** W tym celu trzeba zapytanie z nastepnego komentarza wkleic do nowego okna
*/

/*

DECLARE @ile_zadano_cech int

CREATE TABLE #wymagane_cechy (id_wartosci int not null)
insert into #wymagane_cechy (id_wartosci) VALUES (1)
insert into #wymagane_cechy (id_wartosci) VALUES (5)

SELECT @ile_zadano_cech = COUNT(*) FROM #wymagane_cechy

SELECT f.*
	FROM firmy f
	WHERE f.nazwa_skr IN
	( SELECT fcw.id_firmy
		FROM FIRMY_CECHY fcw
		join #wymagane_cechy ww ON (fcw.id_wartosci = ww.id_wartosci)
		GROUP BY fcw.id_firmy
		HAVING COUNT(*) = @ile_zadano_cech
	)
	ORDER BY f.nazwa

DROP TABLE #wymagane_cechy

*/

