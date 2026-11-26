# Tablica priorytetów UR – uruchomienie

Aplikacja to jeden plik `index.html`. Dopóki w pliku nie ma danych Supabase, działa w **trybie demonstracyjnym**: ma przykładowe dane, które zapisują się tylko w tej jednej przeglądarce. Po podpięciu Supabase wszystkie urządzenia (telewizor, telefony, komputer) widzą te same dane na żywo.

## 1. Baza danych – Supabase (ok. 10 min)

1. Na supabase.com załóż **nowy projekt**, osobny od Wall of Fame, np. `tablica-ur`. Region: Frankfurt (eu-central-1).
2. Wejdź w **SQL Editor → New query**, wklej całą zawartość pliku `schema.sql` i kliknij **Run**.
3. Załóż wspólne konto działu: **Authentication → Users → Add user → Create new user**. Podaj e-mail i hasło i zaznacz *Auto confirm user*.
4. Zablokuj samodzielne zakładanie kont: **Authentication → Sign In / Providers**, wyłącz *Allow new users to sign up*.
5. Skopiuj dane połączenia z **Project Settings → API**:
   - **Project URL**,
   - klucz **anon public**.

## 2. Konfiguracja pliku

Na początku skryptu w `index.html` jest sekcja `CONFIG`. Uzupełnij ją:

```js
SUPABASE_URL:'https://twojprojekt.supabase.co',
SUPABASE_ANON_KEY:'eyJ...',
LINES:['A30','F08','K40','F15a','C32','N02','N16'],
LEADER_PIN:'1234',      // zmień!
STALE_HOURS:8
```

Klucz *anon* może być widoczny publicznie. Dane chroni logowanie wspólnym kontem. PIN to tylko blokada wygody, a nie zabezpieczenie, bo da się go odczytać w kodzie strony.

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

## Jak działa przekazanie zmiany

- Każdy otwarty priorytet musi zostać **przejęty** przez nową zmianę: ktoś otwiera kartę i klika „Przejmuję”. Do tego czasu karta pulsuje na żółto.
- Jeśli przy priorytecie przez **8 godzin** (cała zmiana) nie pojawi się żaden wpis, karta robi się czerwona z napisem „Brak działań od X h”.
- **Raport zmiany** składa się sam z wpisów. Dla każdego priorytetu, przy którym zmiana nic nie zrobiła, pojawia się dopisek „BRAK DZIAŁAŃ NA TEJ ZMIANIE”.
- **Podobne przypadki z historii** pokazują rozwiązania podobnych awarii z tej samej linii. To zalążek przyszłych sugestii AI.

---

## Dalszy rozwój w Claude Code

Otwórz repozytorium `tablica-ur` w Claude Code (claude.ai/code) i wklej poniższy prompt. Na początek wybierz jeden lub dwa punkty z listy.

> To jest aplikacja „Tablica priorytetów UR” do przekazania zmiany w dziale utrzymania ruchu (3 zmiany: 6–14, 14–22, 22–6). Jeden plik index.html, baza Supabase (tabele issues i entries – schemat w schema.sql), logowanie wspólnym kontem, widok TV pod #tv. Zachowaj obecny wygląd i logikę przejmowania priorytetów. Kolejne kroki:
> 1. Tabela `lines` w Supabase (ok. 100 linii) z ekranem do zarządzania zamiast listy w CONFIG.
> 2. Konta osób uprawnionych do dodawania priorytetów (role w Supabase) zamiast PIN-u.
> 3. Paginacja – Supabase domyślnie zwraca maks. 1000 wierszy; na tablicę ładuj otwarte + ostatnie 30 dni, historię wyszukuj po stronie bazy.
> 4. Automatyczna wysyłka raportu zmiany e-mailem o 6:00, 14:00 i 22:00 (Supabase Edge Function + cron).
> 5. Obsługa weekendów (zmiany sobotnie/niedzielne opcjonalne – nie oznaczaj „brak działań” w dni bez pracy).
> 6. Sugestie rozwiązań AI: Edge Function wywołująca Claude API z opisem nowej awarii i podobnymi zamkniętymi przypadkami z bazy; wynik jako sekcja „Sugestia AI” w karcie.
> 7. Przy wpisie „Zrobione” – pole na zużyte części zamienne (indeks, ilość), żeby powiązać awarie z magazynem części.
