# Tablica priorytetów UR – kontekst projektu

Aplikacja do przekazywania zmiany w dziale utrzymania ruchu (UR) zakładu produkcyjnego.
Właściciel: Spare Parts Manager. Użytkownicy: mechanicy na 3 zmianach i liderzy. Język interfejsu: polski.

## Problem, który rozwiązujemy
Priorytety z 1. zmiany nie były przekazywane dalej, a kolejne zmiany nie podejmowały działań.
Kluczowa zasada: otwarty priorytet nie może zniknąć. Każda zmiana musi go przejąć,
a brak wpisów przez całą zmianę jest wyraźnie sygnalizowany.

## Stan obecny
- Jeden plik `index.html` (HTML + CSS + JS, bez frameworka i bez kroku budowania), hostowany na GitHub Pages:
  https://kowalarek88.github.io/tablica-ur/ (widok TV: `#tv`, inne widoki: `#historia`, `#raport`).
- Baza Supabase (projekt `tablica-ur`): tabele `issues`, `entries`, `lines`, `user_roles`. Schemat = pliki w `migrations/`
  uruchamiane po kolei (001 schemat bazowy, 002 role liderów i triggery, 003 linie).
  RLS: dostęp tylko dla zalogowanych, bez kasowania danych (pełna historia).
- Logowanie: wspólne konto działu dla mechaników (nazwisko wpisywane ręcznie, pamiętane w localStorage)
  oraz własne konta liderów (rola w `user_roles`, nadawana w SQL Editorze: `select nadaj_lidera('e-mail','Imię Nazwisko');`).
- Uprawnienia pilnuje baza (RLS + triggery z 002): priorytet dodaje tylko lider; ważność/linię/opis/LDS zmienia tylko lider
  (wpis `edycja` tworzy trigger); status – w tym zamknięcie – każdy. Wpisy `utworzenie` i `edycja` tworzy wyłącznie baza.
- Serwer nadaje `created_at` i `shift_key` (funkcja `shift_key()`, czas Europe/Warsaw); status karty zmienia trigger
  na podstawie `entries.status`. Tryb demo w `index.html` naśladuje te triggery – zmieniając je, zmień oba miejsca.
- Aplikacja pobiera tabele porcjami po 1000 wierszy (`remote.all`) i pokazuje czerwony komunikat przy braku połączenia.
- Bez Supabase w CONFIG aplikacja działa w trybie demo (localStorage + dane przykładowe).

## Reguły biznesowe
- Zmiany: I 06–14, II 14–22, III 22–06 (pon–pt, weekendy czasem). Klucz zmiany: `RRRR-MM-DD-Z{n}`, gdzie zmiana III należy do dnia, w którym się zaczęła.
- Priorytety: W (Wysoki), S (Średni), N (Niski). Dodają je i zmieniają ich ważność tylko liderzy (własne konta).
  Priorytetowe maszyny wskazują kierownicy produkcji na cotygodniowym spotkaniu MPS.
- Statusy: nowe, w_trakcie, czeka_czesc, czeka_postoj, rozwiazane.
- Wpisy (`entries.kind`): utworzenie, komentarz, zrobione, do_zrobienia, status, przejecie.
- „Czeka na przejęcie”: otwarty priorytet bez wpisu `przejecie` z `shift_key` bieżącej zmiany (chyba że utworzony na tej zmianie).
- „Brak działań”: brak wpisu innego niż przejęcie przez `STALE_HOURS` (8 h).
- Awarie są też rejestrowane w firmowym systemie LDS; w karcie zapisujemy tylko numer zgłoszenia LDS (bez integracji).
- Linie (tabela `lines`): numer, sektor, kierownik sektora, technolog, automatyk, osoba z działu NJ, uwagi, `active`.
  Linii się nie kasuje (`active=false`). Testowe: A30, F08, K40, F15a, C32, N02, N16. Docelowo ok. 100 linii.

## Sprzęt
- TV działu: Samsung QB75N (75"), sterowany z podpiętego firmowego komputera (Chrome, tryb pełnoekranowy). Alternatywa: Samsung Flip Pro 55.
- Mechanicy używają telefonów (przeglądarka). Notatki głosowe działają przez Web Speech API (pl-PL).

## Zasady pracy nad kodem
- Zachowaj działanie widoku TV: duże fonty w jednostkach vw, czytelność z kilku metrów, brak przewijania przy typowej liczbie kart.
- Każda wartość z bazy trafiająca do HTML musi przejść przez `esc()`.
- Zmiany schematu bazy dopisuj jako nowe pliki SQL (`migrations/004_….sql` itd.) z instrukcją, gdzie je uruchomić w Supabase;
  pisz je tak, by ponowne uruchomienie niczego nie psuło.
- Niczego nie kasuj z historii; zamykanie = status `rozwiazane` + `closed_at`.
- Właściciel nie jest programistą: po zmianach wyjaśniaj prostym językiem, co zrobić (np. co kliknąć w Supabase).

## Plan rozwoju (kolejność do ustalenia z właścicielem)
1. ~~Tabela `lines` + ekran zarządzania~~ – zrobione (migracja 003, zakładka `#linie`).
2. ~~Konta liderów zamiast PIN-u~~ – zrobione (migracja 002).
3. Paginacja (limit 1000 wierszy w Supabase).
4. Automatyczny e-mail z raportem zmiany o 6:00, 14:00, 22:00 (Edge Function + cron).
5. Obsługa weekendów.
6. Sugestie rozwiązań AI (Edge Function + Claude API, na podstawie podobnych zamkniętych przypadków).
7. Zużyte części zamienne przy wpisie „Zrobione” (indeks, ilość) – powiązanie z magazynem części.
