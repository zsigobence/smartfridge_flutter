# SmartFridge Sync

Többfelhasználós háztartási élelmiszer-nyilvántartó alkalmazás Flutter és Firebase alapokon. A háztartás tagjai közösen tartják számon a hűtő tartalmát: vonalkód-szkennelés segítségével adják hozzá a termékeket, az alkalmazás figyeli a lejárati dátumokat és értesítést küld, ha valami hamarosan lejár. Közös bevásárlólista és valós idejű szinkronizáció egészíti ki a funkciókat.

## Főbb funkciók

- Vonalkód-szkennelés és automatikus termékadat-kitöltés (Open Food Facts API)
- Lejárati dátum követése színkódolt státusszal (lejárt / hamarosan lejár / friss)
- Többfelhasználós háztartások QR-kódos meghívóval
- Megosztott, valós idejű bevásárlólista
- Helyi értesítések lejárat napján
- Android kezdőképernyős widget sürgős elemekhez
- Sötét/világos témamód

## Technológiák

- **Flutter** — cross-platform UI
- **Firebase Auth** — felhasználókezelés (e-mail/jelszó + Google Sign-In)
- **Cloud Firestore** — valós idejű adatbázis
- **Provider** — állapotkezelés
- **mobile_scanner** — vonalkód-olvasó
- **flutter_local_notifications** — helyi értesítések

## Fejlesztési módszertan — AI-driven programming

Az alkalmazás teljes egészében **AI-vezérelt fejlesztési módszertannal** készült, a [Claude Code](https://claude.ai/code) CLI eszköz segítségével, **Antigravity üzemmódban**.

A folyamat a következőképpen zajlott:

1. **Tervezési fázis:** Először az AI generálta le az architektúra- és stílusdokumentumot (`architecture_and_style.md`), amelyben megtervezte a mappastruktúrát, az architekturális döntéseket és a kódolási konvenciókat. Ezt követte a fejlesztési mérföldkövek dokumentuma (`development_steps.md`).

2. **Fejlesztési fázis:** A tényleges kódolás a két tervdokumentum alapján haladt — minden prompt hivatkozott az aktuális mérföldkőre, az AI pedig az előre meghatározott konvenciók szerint generálta a kódot.

3. **Iteratív javítás:** A fejlesztés során előkerülő hibákat és edge case-eket szintén promptokon keresztül kezeltük.

A teljes prompt-történet megtalálható: **[`prompts_log.md`](prompts_log.md)**

A tervdokumentumok:
- [`architecture_and_style.md`](architecture_and_style.md) — mappastruktúra, architekturális döntések, kódolási konvenciók
- [`development_steps.md`](development_steps.md) — fejlesztési mérföldkövek

## Futtatás

A `firebase_options.dart` és a `google-services.json` fájlok nincsenek a repóban (`.gitignore`). Saját Firebase projekt esetén:

```bash
flutterfire configure
flutter pub get
flutter run
```
