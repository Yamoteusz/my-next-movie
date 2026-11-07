# Uruchomienie laboratoriów 3–5

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
