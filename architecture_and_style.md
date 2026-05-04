# Architecture & Style Guide — SmartFridge Sync

## 1. Projekt áttekintés

A **SmartFridge Sync** egy Flutter-alapú, többfelhasználós háztartási élelmiszer-nyilvántartó alkalmazás. A cél az, hogy egy háztartás tagjai közösen tarthassák számon a hűtőben lévő élelmiszerek lejárati idejét, vonalkód-szkennelés segítségével tölthessék fel a készletet, és közös bevásárlólistát vezessenek. A backend Firebase ökoszisztémára fog épülni, valós idejű szinkronizációval.

---

## 2. Tervezett mappastruktúra

```
lib/
├── main.dart
├── firebase_options.dart
├── models/
│   ├── fridge_item.dart
│   ├── household.dart
│   └── shopping_item.dart
├── providers/
│   ├── auth_provider.dart
│   ├── household_provider.dart
│   └── theme_provider.dart
├── services/
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── notification_service.dart
│   ├── open_food_facts_service.dart
│   └── local_image_cache_service.dart
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── home/
│   │   └── home_screen.dart
│   ├── household/
│   │   └── household_screen.dart
│   ├── items/
│   │   ├── add_item_screen.dart
│   │   ├── batch_add_screen.dart
│   │   └── scanner_screen.dart
│   └── shopping/
│       └── shopping_list_screen.dart
└── widgets/
    ├── fridge_item_card.dart
    └── expiry_badge.dart
```

---

## 3. Architekturális döntések

### 3.1 Rétegelt architektúra

A projektet háromrétegű felépítésben tervezzük, hogy a felelősségek tisztán el legyenek választva:

| Réteg | Mappa | Felelősség |
|---|---|---|
| **Prezentációs réteg** | `screens/`, `widgets/` | UI megjelenítés, felhasználói interakciók |
| **Állapot / logikai réteg** | `providers/` | Alkalmazásállapot kezelése |
| **Adat / szolgáltatási réteg** | `services/`, `models/` | Adatforrásokkal való kommunikáció |

Ez a szeparáció azt a célt szolgálja, hogy a képernyők ne tartalmazzanak közvetlen Firebase hívásokat, és az egyes rétegek egymástól függetlenül fejleszthetők legyenek.

### 3.2 Állapotkezelés: Provider + ChangeNotifier

Állapotkezelésre a `provider` csomagot választottuk. Minden fő üzleti tartomány saját `ChangeNotifier`-t kap, amelyek a `MultiProvider`-en keresztül lesznek elérhetők az egész widgetfában:

- **`AuthProvider`** — a bejelentkezett felhasználó állapota és az autentikációs műveletek.
- **`HouseholdProvider`** — az aktív háztartás, az élelmiszer-lista és a bevásárlólista kezelése.
- **`ThemeProvider`** — témapreferencia, `SharedPreferences`-szel perzisztálva.

### 3.3 Valós idejű adatszinkronizáció

Az élelmiszer-elemek és a bevásárlólista Firestore `Stream`-eken keresztül fognak érkezni, így a UI-nak nem kell manuálisan polloznia az adatokat — minden változás automatikusan megjelenhet a többi háztartástag eszközén is.

### 3.4 Adatbázis-séma (Firestore)

```
households/
  └── {householdId}/
        ├── name, inviteCode, members[], createdBy, createdAt
        ├── items/
        │     └── {itemId}
        └── shoppingItems/
              └── {itemId}

users/
  └── {uid}/
        ├── username, email
        └── householdIds[]
```

Az alkollekció-alapú struktúrát azért választottuk, mert így az egyes háztartások adatai természetesen el vannak izolálva egymástól, és a Firestore biztonsági szabályok is könnyen alkalmazhatók lesznek.

### 3.5 Navigáció

Egyszerű, imperatív navigációt (`Navigator.push` / `Navigator.pop`) tervezünk. A gyökéren egy `_RootNavigator` fog dönteni a bejelentkező- és főképernyő között az `AuthProvider` állapota alapján. A főképernyőn `DefaultTabController` fogja kezelni a három fő fület.

---

## 4. Kódolási stílus és konvenciók

### 4.1 Elnevezési konvenciók

| Elem | Konvenció | Példa |
|---|---|---|
| Fájlok | `snake_case` | `fridge_item_card.dart` |
| Osztályok, widgetek | `UpperCamelCase` | `FridgeItemCard` |
| Változók | `lowerCamelCase` | `expiryDate` |
| Privát tagok | `_lowerCamelCase` | `_isLoading` |

### 4.2 Model osztályok

Minden model Firestore-kompatibilis szerializációs logikát fog tartalmazni, és `copyWith` copy constructorral fog rendelkezni az immutábilis állapotfrissítésekhez. A lejárattal kapcsolatos számítások a modelen belül lesznek, nem a UI-ban, hogy a logika ne legyen szétszórva.

### 4.3 Provider stílus

Az állapotváltozók privát mezők lesznek. Hibakezelés `try/catch` blokkokkal: a hibák egy publikus `String` property-n keresztül jutnak a UI-ra, ahol SnackBar-ban jelennek meg. Az aszinkron műveletek `_isLoading` flag-et kezelnek a töltési visszajelzéshez.

### 4.4 Widget stílus

A `context.watch` az újraépítést igénylő helyeken, a `context.read` az event handlerekben lesz használva. A `StatefulWidget` / `StatelessWidget` közötti választás a szükséges lokális állapot alapján dől el.

### 4.5 Design patternek

| Pattern | Hol tervezzük alkalmazni |
|---|---|
| **Service / Repository** | A Firebase hívások service osztályokban, nem providerekben |
| **Observer** | Firestore Streams + `notifyListeners()` |
| **Debounce** | Gyors, ismétlődő Firestore írások elkerülésére (pl. mennyiség-frissítés) |

### 4.6 Formázás

A projekt a Dart alapértelmezett `dart format` stílusát követi. Importok sorrendje: Dart core → Flutter → harmadik fél → saját fájlok.
