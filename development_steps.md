# Development Steps — SmartFridge Sync

Az alkalmazás fejlesztési folyamatának mérföldkövei, az AI-vezérelt (AI-driven programming) módszertan alapján.

---

## Mérföldkő 1 — Projekt inicializálása és Firebase integráció

**Cél:** Működő Flutter projekt alapjainak lerakása a szükséges függőségekkel és a backend összeköttetéssel.

Az első lépés a `pubspec.yaml` összeállítása volt a tervezett csomagokkal: `firebase_core`, `firebase_auth`, `cloud_firestore`, `provider`, `google_sign_in`. A Firebase projektet a Console-ban konfiguráltuk, majd a `flutterfire configure` eszközzel generáltuk le a `firebase_options.dart`-ot. Az alkalmazás indulási sorrendjekor szükségessé vált a `WidgetsFlutterBinding.ensureInitialized()` meghívása a Firebase init előtt — ezt csak futtatáskor derítettük ki.

---

## Mérföldkő 2 — Adatmodellek definiálása

**Cél:** A Firestore adatbázisban tárolandó entitások Dart-osztályokként való meghatározása, mielőtt bármilyen UI-t írnánk.

Elsőként a `FridgeItem`, `Household` és `ShoppingItem` modelleket hoztuk létre. Hamar kiderült, hogy a lejárati logikát (felnyitott termék rövidebb lejárata) érdemes már a modellbe beépíteni computed property-ként, mert különben minden képernyőn külön kellene kiszámolni. A Firestore szerializációhoz `fromFirestore` / `toFirestore` pár és `copyWith` konstruktor lett bevezetve minden modellhez.

---

## Mérföldkő 3 — Hitelesítési rendszer

**Cél:** Biztonságos felhasználói regisztráció és bejelentkezés, felhasználónévvel és Google-fiókkal egyaránt.

Az `AuthService` a Firebase Auth SDK köré írt wrapper lett. Az `AuthProvider` felveszi és terjeszti az autentikációs állapotot. Kicsit bonyolultabbnak bizonyult a felhasználónév-alapú bejelentkezés, mert a Firebase Auth csak e-maillel dolgozik — ezért a Firestore `users` gyűjteménybe kellett menteni a felhasználónév → e-mail leképezést. A `LoginScreen` és `RegisterScreen` megírása viszonylag egyenes volt, bár az űrlap-validáció finomhangolása több iterációt igényelt.

---

## Mérföldkő 4 — Háztartáskezelés és Firestore séma

**Cél:** Több háztartás támogatása és a meghívókód-rendszer kiépítése.

A Firestore sémát alkollekciók köré terveztük: `households/{id}/items` és `households/{id}/shoppingItems`. A meghívókódhoz UUID v4-alapú `FRIDGE-XXXXXX` formátumot választottunk. A `HouseholdProvider` lett az a réteg, amely a streameket kezeli és háztartás-váltáskor le- és feliratkozik. Visszatekintve ez a provider lett a legkomplexebb osztály a projektben. QR-kód generálás (`qr_flutter`) is bekerült a meghívási folyamatba, mert egyszerűbb megosztást tesz lehetővé.

---

## Mérföldkő 5 — Vonalkód-szkennelés és Open Food Facts integráció

**Cél:** A kézi adatbevitel minimalizálása vonalkód-olvasóval és nyilvános termékadatbázissal.

A `mobile_scanner` csomag integrálása viszonylag zökkenőmentes volt. Két módot valósítottunk meg: egyszeres és kötegelt szkennelés. Az Open Food Facts API-val volt egy korai null safety probléma — az API válaszban egyes mezők hiányozhatnak, de a kód eleinte egyszerű castolással próbálkozott. Ez futásidejű hibát okozott, amelyet külön javítási körben kellett kezelni.

---

## Mérföldkő 6 — Élelmiszer hozzáadása és szerkesztése

**Cél:** A termékek részletes adatainak rögzítésére alkalmas képernyő elkészítése.

Az `AddItemScreen` kettős szerepet kapott: új elem hozzáadása és meglévő szerkesztése. A képek kezelése külön `LocalImageCacheService`-t indokolt, hogy ne kelljen minden alkalommal hálózatról tölteni a már ismert termékképeket. A `BatchAddScreen` a kötegelt szkennelés eredményeit dolgozza fel egy listás nézetben, ahol a felhasználó egyszerre adhatja hozzá az összes beolvasott terméket.

---

## Mérföldkő 7 — Főképernyő és lejárati logika

**Cél:** Az élelmiszer-lista áttekinthető megjelenítése, a sürgős elemek kiemelésével.

A `HomeScreen` három fület kapott (`DefaultTabController`): lejáró/sürgős, friss, és összes. A `FridgeItemCard` és `ExpiryBadge` widgetek újrafelhasználható komponensként lettek kiemelve, hogy ne kelljen minden fülön külön implementálni a megjelenítési logikát. A figyelmeztető banner (lejárt elemekhez) és a keresési funkció fejlesztés közben, felhasználói igény alapján került be.

---

## Mérföldkő 8 — Bevásárlólista

**Cél:** Megosztott, valós idejű bevásárlólista háztartásonként.

A `ShoppingListScreen` a többi Firestore-integrált képernyőhöz képest viszonylag egyszerűnek bizonyult, mivel a stream-alapú minta már ki volt dolgozva. Checkbox-os jelölés, mennyiség-módosítás és tömeges törlés kerültek be. A lista üres állapotához egy külön üzenet segít a felhasználónak megérteni, mit kell tennie.

---

## Mérföldkő 9 — Értesítések és Home Widget

**Cél:** Proaktív értesítések lejáró termékekről az alkalmazáson kívül is.

A `flutter_local_notifications` integráció kezdetben nem működött Android emulátoron — hiányoztak az `AndroidManifest.xml`-ből a szükséges bejegyzések. Ezután az értesítések ütemezése időzóna-tudatosan lett megvalósítva (`flutter_timezone`), minden elem lejáratának napjára reggel 8:00-ra. A `home_widget` csomaggal Android kezdőképernyős widget is elkészült a sürgős elemek megjelenítéséhez.

---

## Mérföldkő 10 — Téma, adatmigráció és hibajavítások

**Cél:** Az alkalmazásélmény csiszolása és a fejlesztés során felgyülemlett technikai adósság törlesztése.

Sötét/világos témaváltás lett hozzáadva `ThemeProvider`-rel, zöld Material 3 seed színnel. Kiderült, hogy a korai fejlesztésű felhasználói dokumentumokban még egyszeres `householdId` string szerepelt tömb helyett — ezt migrációs logikával kellett kezelni, hogy a régi adatok ne törjenek el. A mennyiség-frissítés gombokhoz debouncing lett bevezetve, mert teszteléskor kiderült, hogy gyors kattintgatáskor rengeteg felesleges Firestore írás keletkezett.
