# Prompts Log — SmartFridge Sync (AI-Driven Development)

Az alábbiakban azok a promptok szerepelnek, amelyekkel a projektet nulláról a jelenlegi állapotára hoztam a Claude Code segítségével. Kizárólag a felhasználói promptok szerepelnek sorrendben.

---

**[Prompt 01]**
Szeretnék készíteni egy Flutter alkalmazást hűtőnyilvántartásra. Több felhasználó tudja majd közösen használni, vonalkód-szkennelés segítségével lehet felvenni az elemeket, és lejárati dátum alapján figyelmeztet. A backend Firebase legyen (Auth, Firestore). Mielőtt elkezdenénk a kódolást, kérlek generálj egy fájlt, amelyben megtervezed a mappastruktúrát, az architekturális döntéseket és a kódolási konvenciókat, amelyeket a teljes fejlesztés során követni fogunk!

---

**[Prompt 02]**
Az architektúra dokumentum alapján kérlek generálj egy olyan fájlt is, ahol mérföldkövekre bontod a fejlesztési folyamatot! Az egyes lépések logikusan épüljenek egymásra, és igazodjanak az architecture_and_style.md-ben leírt tervhez.

---

**[Prompt 03]**
Kezdjük a fejlesztést a development_steps.md alapján. Az 1. és 2. mérföldkőt csináljuk meg egyszerre. Inicializáld a projektet és hozd létre a három adatmodellt (FridgeItem, Household, ShoppingItem) az architecture dokumentumban leírt konvenciók szerint!

---

**[Prompt 04]**
Folytassuk a 3. mérföldkővel. Az architecture_and_style.md-ben meghatározott rétegelt architektúra alapján csináld meg a teljes autentikációs réteget. Fontos, hogy felhasználónévvel lehessen bejelentkezni és Google fiókkal is, és a Firebase hibakódokat magyar hibaüzenetekre fordítsd!

---

**[Prompt 05]**
A 4. mérföldkő következik. Implementáld a háztartáskezelést a tervezett Firestore séma alapján: FirestoreService, HouseholdProvider, HouseholdScreen. A meghívókód legyen egyedi, és legyen QR-kód alapú megosztás is.

---

**[Prompt 06]**
Az előző kódnál ez a hiba jött teszteléskor:


type 'Null' is not a subtype of type 'String' in type cast
#0 OpenFoodFactsService.lookupBarcode (open_food_facts_service.dart:24)


Az Open Food Facts API nem ad vissza minden mezőt minden terméknél. Javítsd ki a problémát, majd folytasd az 5. mérföldkővel: teljes vonalkód-szkenner integráció (ScannerScreen, OpenFoodFactsService, BatchAddScreen, AddItemScreen, LocalImageCacheService).

---

**[Prompt 07]**
Csináljuk meg a 7. és 8. mérföldkőt. A HomeScreen-t három füllel (sürgős / friss / összes), a FridgeItemCard és ExpiryBadge widgeteket, és a ShoppingListScreen-t. 

---


**[Prompt 08]**
Fejezzük be a development_steps.md 10. mérföldkövével. Csináld meg a ThemeProvider-t zöld Material 3 seed színnel.