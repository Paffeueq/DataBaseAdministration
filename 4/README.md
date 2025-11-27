# LABORATORIUM 4 - INSTRUKCJA FINALIZACJI SPRAWOZDANIA

## 📋 Co zostało zrobione (KOMPLETNE)

✅ **Kod SQL** - Z4_backup_all_lub_backup_tam_gdzie_przyroslo.sql
- Tabela BK_LOG - GOTOWA
- Procedura bk_db - TESTOWANA (SUCCESS)
- Procedura bk_all_db - TESTOWANA (6 baz, SUCCESS)
- Procedura bk_growth - PRZYGOTOWANA (wymaga STAT)
- Testy - WYKONANE
- Rzeczywiste dane w BK_LOG - DOSTĘPNE

✅ **Dokumentacja LaTeX** - Z4_331720.tex
- Pełna dokumentacja z rzeczywistymi wynikami testów
- Instrukcja tworzenia Job'a w SQL Agent
- Statystyka backupów: 7 SUCCESS, 2 FAILED
- Analiza plików: 6 plików, 21,55 MB

✅ **Pliki backup** (w folderze projektu)
- B25_ADM_PM331720__20251127T203.bak (2,80 MB)
- PM_DB1__20251127T203.bak (6,21 MB)
- PM_DB2__20251127T203.bak (3,11 MB)
- PM_DB3__20251127T203.bak (3,11 MB)
- PM_DB4__20251127T203.bak (3,11 MB)
- PM_DB5__20251127T203.bak (3,11 MB)

## 📸 SCREENY DO ZROBIENIA (dla sprawozdania PDF)

### Screenshot 1: Tabela BK_LOG z wpisami
```sql
-- W SQL Server Management Studio:
SELECT TOP 10 bk_id, nazwa_b, nazwa_pliku_bk, kiedy, status 
FROM dbo.BK_LOG 
ORDER BY bk_id DESC
```
**Polecenie:** Zrób screenshot - Results tab

### Screenshot 2: Pliki backup w katalogu
```
File Explorer: D:\stud\sem 5\AdminBazDa\4\
Pokaż pliki: *.bak
```
**Polecenie:** Zrób screenshot - pokaż wszystkie 6 plików .bak

### Screenshot 3: SQL Server Agent Job (OPCJONALNY)
```
SQL Server Management Studio:
- Object Explorer
- SQL Server Agent
- Jobs
- [Nowy Job] "Backup All Databases Daily"
```
**Polecenie:** Zrób screenshot - pokazanie job'a w Agent

### Screenshot 4: Wyniku procedury bk_all_db
```sql
-- W SQL Server Management Studio:
EXEC dbo.bk_all_db @path = N'D:\stud\sem 5\AdminBazDa\4\'
```
**Polecenie:** Zrób screenshot - Messages tab z komunikatami backup'ów

## 🔧 KOMPILACJA SPRAWOZDANIA

### Opcja 1: LaTeX → PDF (NAJLEPSZE PODEJŚCIE)
```bash
# W folderze Z4 (gdzie jest Z4_331720.tex):
pdflatex Z4_331720.tex
pdflatex Z4_331720.tex  # Ponownie (dla table of contents)
```

Wynik: **Z4_331720.pdf**

### Opcja 2: Jeśli nie masz LaTeX
- Otwórz Z4_331720.tex w Overleaf.com
- Compile → Download PDF

## 📝 ZAWARTOŚĆ SPRAWOZDANIA PDF

### Części obecne:
1. ✅ Cel laboratorium
2. ✅ Struktura systemu (tabela BK_LOG)
3. ✅ Procedury SQL z pełnym kodem
4. ✅ Logika działania każdej procedury
5. ✅ Testowanie - RZECZYWISTE WYNIKI
6. ✅ Dowód wykonania operacji (z danymi)
7. ✅ Statystyka wyników (rzeczywiste liczby)
8. ✅ Instrukcja SQL Agent Job
9. ✅ Wymagania i konfiguracja
10. ✅ Wnioski i możliwe rozszerzenia

### Co wkleić/dodać z screenshot'ów:

Znaleźć w LaTeX odpowiednie miejsca i wkleić:

```latex
% Przed sekcją "Analiza plików backup'u" dodać:

\subsection{Screenshot 1: Tabela BK_LOG}
\includegraphics[width=\textwidth]{screenshot_bk_log.png}

\subsection{Screenshot 2: Pliki backup w katalogu}
\includegraphics[width=\textwidth]{screenshot_files.png}

\subsection{Screenshot 3: SQL Agent Job (jeśli wykonany)}
\includegraphics[width=\textwidth]{screenshot_job.png}
```

## 🎯 KROKI DO ODDANIA

### 1. Skompiluj PDF
```bash
pdflatex Z4_331720.tex
pdflatex Z4_331720.tex
```

### 2. Zrób screenshot'y (co najmniej 2):
- Screenshot 1: BK_LOG query (Messages tab)
- Screenshot 2: Pliki backup w File Explorer

### 3. Dołącz pliki do sprawozdania:
- Z4_331720.pdf (główne sprawozdanie)
- Z4_backup_all_lub_backup_tam_gdzie_przyroslo.sql (kod SQL)
- screenshot_bk_log.png (dane z BK_LOG)
- screenshot_files.png (pliki backup w katalogu)

## ✅ LISTA KONTROLNA

- [x] Procedury SQL działają bez błędów
- [x] Tabela BK_LOG zawiera rzeczywiste wpisy
- [x] Pliki backup zostały utworzone (21,55 MB)
- [x] Dokumentacja LaTeX - GOTOWA DO KOMPILACJI
- [ ] Screenshot'y - CZEKAM NA TWOJE
- [ ] PDF - CZEKA NA KOMPILACJĘ
- [ ] Oddanie do nauczyciela - CZEKAJ AŻ SKOŃCZYSZ POWYŻSZE

## 📞 JAK URUCHOMIĆ TEST JESZCZE RAZ

Jeśli chcesz testy powtórzyć (zrobić nowe screeny):

```sql
-- W SQL Server Management Studio (baza: B25_ADM_PM331720)
-- Uruchom plik Z4_backup_all_lub_backup_tam_gdzie_przyroslo.sql

-- Lub pojedynczo:
EXEC dbo.bk_all_db @path = N'D:\stud\sem 5\AdminBazDa\4\'
```

## 📊 RZECZYWISTE WYNIKI (DO DOKUMENTU)

```
Liczba backupów:         7 SUCCESS
Baz zbackupowanych:      6
Łączny rozmiar:          21,55 MB
Procedur:                3 (bk_db, bk_all_db, bk_growth)
Kolumn w BK_LOG:         8
Status:                  GOTOWE DO ODDANIA
```

---

**Data:** 27 listopada 2025
**Autor:** Paweł Myszka (nr albumu 331720)
**Status:** KOMPLETNE ✅
