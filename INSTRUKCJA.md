# Tablica priorytetów UR – uruchomienie

Aplikacja to jeden plik `index.html`. Dopóki w pliku nie ma danych Supabase, działa w **trybie demonstracyjnym**: ma przykładowe dane, które zapisują się tylko w tej jednej przeglądarce. Po podpięciu Supabase wszystkie urządzenia (telewizor, telefony, komputer) widzą te same dane na żywo.

## 1. Baza danych – Supabase (ok. 15 min)

Pliki SQL są w folderze `migrations/` i uruchamia się je **po kolei**: każdy przez **SQL Editor → New query → wklej całość → Run**.

| Plik | Co robi | Kiedy |
|---|---|---|
| `001_schema.sql` | tabele zgłoszeń i wpisów | tylko w nowym, pustym projekcie |
| `002_liderzy.sql` | konta liderów, uprawnienia, czas z serwera | raz, przed wgraniem nowej wersji strony |
| `003_linie.sql` | tabela linii (sektor, osoby kontaktowe) | raz, po pliku 002 |

Pliki 002 i 003 można bezpiecznie uruchomić drugi raz, bo nic się nie zdubluje.

1. Na supabase.com załóż **nowy projekt**, osobny od Wall of Fame, np. `tablica-ur`. Region: Frankfurt (eu-central-1).
2. Uruchom kolejno `001_schema.sql`, `002_liderzy.sql` i `003_linie.sql`.
3. Załóż wspólne konto działu: **Authentication → Users → Add user → Create new user**. Podaj e-mail i hasło i zaznacz *Auto confirm user*.
4. Zablokuj samodzielne zakładanie kont: **Authentication → Sign In / Providers**, wyłącz *Allow new users to sign up*.
5. Załóż konta liderów i nadaj im role (rozdział 6).
6. Skopiuj dane połączenia z **Project Settings → API**:
   - **Project URL**,
   - klucz **anon public**.

## 2. Konfiguracja pliku

Na początku skryptu w `index.html` jest sekcja `CONFIG`. Uzupełnij ją:

```js
SUPABASE_URL:'https://twojprojekt.supabase.co',
SUPABASE_ANON_KEY:'eyJ...',
STALE_HOURS:8
```

Klucz *anon* może być widoczny publicznie. Dane chroni logowanie, a uprawnienia liderów sprawdza sama baza. Listy linii i PIN-u nie ma już w pliku: linie są w bazie, a liderzy mają własne konta.

## 3. Publikacja – GitHub Pages

1. Na GitHubie utwórz repozytorium, np. `tablica-ur`. Wgraj do niego `index.html`: **Add file → Upload files**.
2. Wejdź w **Settings → Pages**. Jako źródło ustaw *Deploy from a branch*, gałąź `main`, folder `/ (root)`, i kliknij **Save**.
3. Po 1–2 minutach aplikacja będzie dostępna pod adresem `https://TWÓJ-LOGIN.github.io/tablica-ur/`.

## 4. Telewizor (Samsung QB75N)

- **Przez komputer podpięty do TV:** otwórz w Chrome `https://…/tablica-ur/#tv` i zaloguj się raz (sesja zostaje zapamiętana). Potem naciśnij F11.
  Możesz też zrobić skrót, który od razu otwiera tablicę na pełnym ekranie:
  `chrome.exe --kiosk "https://…/tablica-ur/#tv"`.
  Jeśli tablica ma być widoczna stale, a komputer służy też do innych programów, wygodnie jest ustawić okno Chrome na osobnym pulpicie Windows.
- **Jeśli firmowy komputer lub sieć zablokuje stronę:** użyj Samsunga Flip Pro 55 z jego własną przeglądarką i osobnym internetem. Ekrany serii QB mają też wbudowaną przeglądarkę lub URL Launcher, więc warto sprawdzić to w menu ekranu.
- Tablica odświeża się sama. Nowe wpisy z telefonów pojawiają się na ekranie od razu.

## 5. Telefony mechaników

- Otwórz link i zaloguj się wspólnym kontem. Potem wybierz w przeglądarce **Dodaj do ekranu głównego**, żeby aplikacja miała własną ikonę.
- **Notatki głosowe** (przycisk z mikrofonem) działają w Chrome na Androidzie. Na iPhonie działa to różnie, więc w razie problemów wystarczy mikrofon na klawiaturze telefonu.
- Nazwisko wpisuje się przy pierwszym wpisie. Telefon je zapamiętuje.

## 6. Liderzy (dodawanie priorytetów, zmiana ważności, linie)

Liderzy logują się **własnym kontem**, a mechanicy dalej wspólnym kontem działu.

| Kto | Co może |
|---|---|
| wszyscy zalogowani | przejąć priorytet, dodać wpis, zmienić status (także zamknąć jako „Rozwiązane”), czytać listę linii |
| lider | to samo oraz dodać priorytet, zmienić ważność (W/S/N), linię, opis i nr LDS, dodawać i zmieniać linie |

Baza sama tego pilnuje, więc wspólne konto nie obejdzie zasad nawet poza aplikacją.

**Nowy lider:**
1. **Authentication → Users → Add user → Create new user**: e-mail i hasło lidera, zaznacz *Auto confirm user*.
2. **SQL Editor → New query**, wklej poniższą linijkę (z właściwym e-mailem i nazwiskiem) i kliknij **Run**:
   ```sql
   select nadaj_lidera('jan.nowak@firma.pl', 'Jan Nowak');
   ```
   Powinien pojawić się komunikat `OK: … ma rolę: lider`.

**Odebranie roli:** `select odbierz_role('jan.nowak@firma.pl');`

**Na telefonie lidera:** jeśli telefon był zalogowany wspólnym kontem, kliknij swoje nazwisko w górnym pasku, potem **Wyloguj to urządzenie**, i zaloguj się własnym kontem. Wpisy lidera podpisują się same.

**Zmiana hasła lidera:** **Authentication → Users**, przy koncie **⋯ → Reset password** albo usuń konto i załóż je ponownie. Po ponownym założeniu konta trzeba jeszcze raz nadać rolę.

## 7. Linie

Zakładka **Linie** pokazuje sektor i osoby odpowiedzialne za linię: kierownika sektora, technologa, automatyka i osobę z działu NJ. Te same dane widać w szczegółach każdej karty, żeby mechanik od razu wiedział, do kogo dzwonić.

- Lider dodaje linię przyciskiem **+ Dodaj linię**, a zmienia ją, klikając wiersz.
- **Wklej listę z Excela:** zaznacz w Excelu kolumny *Linia, Sektor, Kierownik sektora, Technolog, Automatyk, Dział NJ* (w tej kolejności), skopiuj i wklej. Istniejące linie zostaną zaktualizowane, nowe dodane. Puste pole nie kasuje danych.
- Linii się nie usuwa: odznacz **Linia aktywna**, a zniknie z listy wyboru, ale jej historia zostanie.

## Jak działa przekazanie zmiany

- Każdy otwarty priorytet musi zostać **przejęty** przez nową zmianę: ktoś otwiera kartę i klika „Przejmuję”. Do tego czasu karta pulsuje na żółto.
- Jeśli przy priorytecie przez **8 godzin** (cała zmiana) nie pojawi się żaden wpis, karta robi się czerwona z napisem „Brak działań od X h”.
- **Raport zmiany** składa się sam z wpisów. Dla każdego priorytetu, przy którym zmiana nic nie zrobiła, pojawia się dopisek „BRAK DZIAŁAŃ NA TEJ ZMIANIE”.
- Godzinę wpisu i zmianę, do której należy, nadaje serwer, a nie zegar telefonu.
- Gdy tablica traci połączenie z bazą, na górze pojawia się czerwony komunikat „Brak połączenia z bazą – dane z godz. …”.
- Zmiana ważności lub danych karty przez lidera zapisuje się w historii karty jako „Zmiana danych (lider)”.
- **Podobne przypadki z historii** pokazują rozwiązania podobnych awarii z tej samej linii. To zalążek przyszłych sugestii AI.

---

## Dalszy rozwój w Claude Code

Otwórz repozytorium `tablica-ur` w Claude Code (claude.ai/code) i wklej poniższy prompt. Na początek wybierz jeden lub dwa punkty z listy.

Kontekst projektu jest w pliku `CLAUDE.md`, więc Claude Code przeczyta go sam. Punkty 1 i 2 (tabela linii i konta liderów) są już zrobione. Pozostałe:

> 3. Paginacja – dziś aplikacja pobiera wszystkie wiersze porcjami po 1000; docelowo na tablicę ładuj otwarte + ostatnie 30 dni, historię wyszukuj po stronie bazy.
> 4. Automatyczna wysyłka raportu zmiany e-mailem o 6:00, 14:00 i 22:00 (Supabase Edge Function + cron).
> 5. Obsługa weekendów (zmiany sobotnie/niedzielne opcjonalne – nie oznaczaj „brak działań” w dni bez pracy).
> 6. Sugestie rozwiązań AI: Edge Function wywołująca Claude API z opisem nowej awarii i podobnymi zamkniętymi przypadkami z bazy; wynik jako sekcja „Sugestia AI” w karcie.
> 7. Przy wpisie „Zrobione” – pole na zużyte części zamienne (indeks, ilość), żeby powiązać awarie z magazynem części.
