# Uruchomienie laboratoriów 3–7

Kod i testy działają bez kont zewnętrznych. Aplikacja wymaga konfiguracji TMDB oraz Supabase, żeby zalogować użytkownika i pobrać filmy.

## Projekt Supabase

Podczas tworzenia projektu:

- Nazwa: `my-next-movie`, region: Europe.
- Wygeneruj silne hasło bazy i zachowaj je w menedżerze haseł.
- Enable Data API: włączone.
- Automatically expose new tables: wyłączone.
- Enable automatic RLS: włączone.

Migracje przyznają zalogowanym użytkownikom odczyt, dodawanie i usuwanie zapisanych filmów. RLS ogranicza operacje do własnych wierszy. Klient nie potrzebuje uprawnień do aktualizacji.

Zainstaluj Supabase CLI zgodnie z `docs/lab5.md`, a następnie w katalogu projektu wykonaj:

```sh
supabase login
supabase link --project-ref TWOJ_PROJECT_REF
supabase db push --include-seed
```

Project ref to identyfikator z adresu panelu `/project/IDENTYFIKATOR`. Migracje są w `supabase/migrations`, konto demonstracyjne tworzy `supabase/seed.sql`.

Sprawdź w panelu: Table Editor → `saved_movies` ma włączone RLS; Authentication → Users zawiera `test@test.test`. Konto testowe ma hasło `test` i jest przeznaczone do ćwiczeń. W Debug formularz je podpowiada, w Release pola są puste.

Możesz pozostawić potwierdzanie emaila włączone. Nowe konta wtedy otrzymają komunikat z prośbą o kliknięcie linku. Wyłączenie potwierdzeń jest opcją opisaną w lab5 dla projektu ćwiczeniowego.

## Klucze

W lokalnym, ignorowanym przez Git `Config/Secrets.xcconfig` wpisz:

```xcconfig
TMDB_API_KEY = TWOJ_TMDB_API_KEY
SUPABASE_URL = https:/$()/TWOJ_PROJECT_REF.supabase.co
SUPABASE_ANON_KEY = TWOJ_KLUCZ_PUBLISHABLE_LUB_ANON
```

TMDB: użyj API key do parametru `api_key`, nie tokenu Bearer. Supabase: skopiuj Project URL i publishable key albo starszy anon key z ustawień projektu. Hasło bazy oraz klucz secret/service_role nie trafiają do aplikacji. Nie dodawaj pliku z kluczami do commita ani ZIP-a oddawanego na zajęciach.

W Xcode: Product → Clean Build Folder (⇧⌘K), potem ⌘R. Do zalogowania kontem ćwiczeniowym wystarczy Sign In. Bez konfiguracji aplikacja wyświetli komunikat o brakujących kluczach.

## Weryfikacja

- ⌘U: testy są lokalne, nie wymagają API ani działającego backendu.
- Lista Movies pobiera filmy z TMDB; Search wyszukuje tekst i filtruje gatunek.
- Szczegóły: hasło, czas, kategoria wiekowa, reżyser, zwiastun, obsada, serwisy oraz polecane filmy.
- Zakładka w szczegółach zapisuje film. Saved pokazuje najnowsze najpierw.
- Return w wyszukiwarce zapisuje frazę w historii. Clear czyści historię.
- Cache przechowuje ostatnią listę i odwiedzone szczegóły. Plakaty wymagają sieci.
- Account pokazuje stan synchronizacji. Zmiany offline czekają na powrót sieci i aktywację aplikacji.
- Drugie urządzenie z tym samym kontem pobiera listę przy aktywacji.
- Wylogowanie najpierw próbuje synchronizacji, a potem usuwa lokalne filmy i znaczniki usunięcia. Niewysłane zmiany mogą zostać utracone przy wylogowaniu offline.

## Lab 6: kina i MapKit

W projekcie jest zakładka Cinemas między Saved i Account. Kino z listy zaznacza pinezkę i przesuwa mapę. Pinezka zaznacza listę i przewija do właściwego wiersza. Przycisk info otwiera szczegóły kina.

W symulatorze ustaw Features → Location → Custom Location: latitude `51.0983`, longitude `17.0368` (Wrocław Główny). Na pytanie aplikacji o lokalizację wybierz dostęp podczas używania aplikacji. Następnie sprawdź:

- odległości na liście oraz najbliższe kina na górze,
- trasy Walk i Drive, przycisk Directions in Maps, telefon i stronę kina,
- Look Around, gdy Apple udostępnia zdjęcia dla danego miejsca,
- po odmowie lokalizacji: listę alfabetyczną i informację o braku odległości,
- Now in Cinemas na filmie z premierą kinową w kraju ustawionym na urządzeniu, od 0 do 42 dni temu; arkusz ma przycisk Done.

Now in Cinemas jest wskazówką opartą na dacie premiery, a nie aktualnym repertuarem. Godziny seansów są na stronach kin. Lista kin jest lokalna; kafelki map, trasy i Look Around wymagają dostępu do usług Apple.

Konfiguracja z upstream ma minimalny iOS 27. Do standardowego uruchamiania projektu potrzebny jest Xcode 27 z odpowiednim SDK i symulatorem. Testy lab6 sprawdzono również na iOS 26.4.1 w osobnej kopii z obniżonym wymaganiem, bez zmiany ustawienia 27.0 w repozytorium.

## Lab 7: wyszukiwanie z AI

Domyślna ścieżka A korzysta z OpenRoutera przez funkcję `movie-filters` w Supabase. Nie wymaga pobierania lokalnego modelu. `LOCAL_MODEL_URL` pozostaje pusty.

Klucz OpenRoutera jest w sekrecie `OPENROUTER_API_KEY` po stronie Supabase. Lokalną kopię przechowuje ignorowany plik `supabase/.env.local`. Nie wpisuj tego klucza do `Config/Secrets.xcconfig`, aplikacji ani plików śledzonych przez Git. Domyślny model to `nvidia/nemotron-3.5-super-vl:free`.

Backend wymaga migracji `20261104171300_create_ai_requests.sql` oraz `20261121120000_ai_requests_api_grants.sql`. Druga przyznaje uprawnienia potrzebne, gdy automatyczne udostępnianie nowych tabel jest wyłączone. RLS pozwala użytkownikowi odczytać i dodać tylko własne pytania; nie pozwala ich usuwać. Funkcja wymaga zalogowania i przyjmuje najwyżej 50 pytań na konto w ciągu 24 godzin.

W istniejącym projekcie baza z lab5 była utworzona bez historii migracji CLI. Migracje lab7 zastosowano osobno, w jednej transakcji. Funkcja i sekret są już wdrożone. Ponowne uruchomienie wszystkich migracji przez `db push` wymaga wcześniejszego uzgodnienia historii migracji z istniejącym schematem.

Do wdrożenia użyto Supabase CLI 3.2.0 i osobnej konfiguracji z `project_id` oraz `[functions.movie-filters]`, z `verify_jwt = true`. Pozwala to zachować konfigurację laboratoriów, która używa jeszcze sekcji `inbucket`, nieobsługiwanej przez CLI 3. Funkcję wdrożono przez `functions deploy movie-filters --use-api`, bez Dockera.

W aplikacji:

- Zaloguj się, otwórz Search i wpisz `matrix`: zwykłe wyszukiwanie nadal działa podczas pisania.
- Wpisz `coś lekkiego z Keanu z lat 90` i wybierz Ask AI albo klawisz wyszukiwania.
- Nad wynikami pojawi się `Comedy · 1990–1999 · Keanu Reeves`.
- Zmiana tekstu lub gatunku przywraca zwykłe wyszukiwanie. Błąd modelu albo brak użytecznych filtrów również uruchamia zwykłe wyszukiwanie, z komunikatem o przyczynie.

Sprawdzono backend dla zdania po angielsku i po polsku: oba dały 8 wyników TMDB oraz po jednym nowym wierszu w `ai_requests`. Wywołanie bez zalogowania zwróciło HTTP 401. Wszystkie 185 testów aplikacji przeszło na iOS 26.4.1 w osobnej kopii z obniżonym wymaganiem systemu; build i lint również przeszły.

Kod zawiera też opcjonalny parser lokalny z zadania 5. Uruchomienie go wymaga samodzielnego uruchomienia `llama-server` zgodnie z `docs/lab7.md` i ustawienia `LOCAL_MODEL_URL` w lokalnym `Config/Secrets.xcconfig` na `http:/$()/127.0.0.1:8080`. Pusta wartość wybiera ponownie chmurę.
