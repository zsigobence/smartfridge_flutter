import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../models/fridge_item.dart';
import '../models/household.dart';
import '../models/shopping_item.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class HouseholdProvider extends ChangeNotifier {
  final _firestoreService = FirestoreService();

  User? _user;
  Household? _household;
  List<Household> _allHouseholds = [];
  List<FridgeItem> _items = [];
  List<ShoppingItem> _shoppingItems = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<FridgeItem>>? _itemsSub;
  StreamSubscription<List<ShoppingItem>>? _shoppingSub;

  Household? get household => _household;
  List<Household> get allHouseholds => _allHouseholds;
  List<FridgeItem> get items => _items;
  List<ShoppingItem> get shoppingItems => _shoppingItems;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasHousehold => _household != null;

  List<FridgeItem> get expiredItems =>
      _items.where((i) => i.isExpired).toList();
  List<FridgeItem> get expiringSoonItems =>
      _items.where((i) => i.isExpiringSoon).toList();
  List<FridgeItem> get freshItems =>
      _items.where((i) => !i.isExpired && !i.isExpiringSoon).toList();

  void updateUser(User? user) {
    if (_user?.uid == user?.uid) return;
    _user = user;
    if (user != null) {
      _loadHouseholds();
    } else {
      _reset();
    }
  }

  Future<void> _loadHouseholds() async {
    _isLoading = true;
    notifyListeners();
    try {
      final ids = await _firestoreService.getUserHouseholdIds(_user!.uid);
      if (ids.isNotEmpty) {
        _allHouseholds = await _firestoreService.getHouseholds(ids);
        if (_allHouseholds.isNotEmpty) {
          _household = _allHouseholds.first;
          _subscribeToItems(_household!.id);
          _subscribeToShoppingItems(_household!.id);
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _subscribeToItems(String householdId) {
    _itemsSub?.cancel();
    _itemsSub = _firestoreService.itemsStream(householdId).listen((items) {
      _items = items;
      NotificationService.scheduleExpiryNotifications(items);
      _updateHomeWidget(items);
      notifyListeners();
    });
  }

  void _subscribeToShoppingItems(String householdId) {
    _shoppingSub?.cancel();
    _shoppingSub =
        _firestoreService.shoppingItemsStream(householdId).listen((items) {
      _shoppingItems = items;
      notifyListeners();
    });
  }

  Future<void> switchHousehold(Household h) async {
    if (_household?.id == h.id) return;
    _itemsSub?.cancel();
    _shoppingSub?.cancel();
    _items = [];
    _shoppingItems = [];
    _household = h;
    _subscribeToItems(h.id);
    _subscribeToShoppingItems(h.id);
    notifyListeners();
  }

  Future<bool> createHousehold(String name) async {
    _error = null;
    try {
      final h = await _firestoreService.createHousehold(name, _user!.uid);
      _allHouseholds = [..._allHouseholds, h];
      _household = h;
      _subscribeToItems(h.id);
      _subscribeToShoppingItems(h.id);
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'Nem sikerült létrehozni a háztartást.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> joinHousehold(String inviteCode) async {
    _error = null;
    try {
      final h = await _firestoreService.joinHousehold(inviteCode, _user!.uid);
      if (h == null) {
        _error = 'Érvénytelen meghívó kód.';
        notifyListeners();
        return false;
      }
      // Ha már tag, csak váltsunk rá
      final existing = _allHouseholds.indexWhere((e) => e.id == h.id);
      if (existing >= 0) {
        _allHouseholds[existing] = h;
      } else {
        _allHouseholds = [..._allHouseholds, h];
      }
      _household = h;
      _subscribeToItems(h.id);
      _subscribeToShoppingItems(h.id);
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'Nem sikerült csatlakozni.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> leaveHousehold() async {
    _error = null;
    try {
      final leaving = _household!;
      await _firestoreService.leaveHousehold(leaving.id, _user!.uid);
      _allHouseholds = _allHouseholds.where((h) => h.id != leaving.id).toList();
      if (_allHouseholds.isNotEmpty) {
        // Van másik háztartás → váltsunk rá
        final next = _allHouseholds.first;
        _household = next;
        _subscribeToItems(next.id);
        _subscribeToShoppingItems(next.id);
      } else {
        // Nincs több háztartás
        _itemsSub?.cancel();
        _shoppingSub?.cancel();
        _household = null;
        _items = [];
        _shoppingItems = [];
      }
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'Nem sikerült kilépni a háztartásból.';
      notifyListeners();
      return false;
    }
  }

  // ── Hűtő termékek ───────────────────────────────────────────────

  Future<void> addItem(FridgeItem item) =>
      _firestoreService.addItem(item);

  Future<void> updateItem(FridgeItem item) =>
      _firestoreService.updateItem(item);

  Future<void> deleteItem(FridgeItem item) =>
      _firestoreService.deleteItem(item);

  Future<FridgeItem?> getItemByBarcode(String barcode) async {
    if (_household == null) return null;
    return _firestoreService.getItemByBarcode(_household!.id, barcode);
  }

  // ── Bevásárlólista ───────────────────────────────────────────────

  Future<void> addShoppingItem(ShoppingItem item) =>
      _firestoreService.addShoppingItem(item);

  Future<void> updateShoppingItem(ShoppingItem item) =>
      _firestoreService.updateShoppingItem(item);

  Future<void> deleteShoppingItem(ShoppingItem item) =>
      _firestoreService.deleteShoppingItem(item);

  Future<void> deleteCheckedShoppingItems() {
    if (_household == null) return Future.value();
    return _firestoreService.deleteCheckedShoppingItems(_household!.id);
  }

  Future<void> _updateHomeWidget(List<FridgeItem> items) async {
    // Minden lejárt vagy 3 napon belül lejáró termék, dátum szerint rendezve
    final urgent = items
        .where((i) => i.daysUntilExpiry <= 3)
        .toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    for (int i = 0; i < urgent.length; i++) {
      final item = urgent[i];
      final days = item.daysUntilExpiry;
      final date = days < 0
          ? 'lejárt!'
          : days == 0
              ? 'ma!'
              : days == 1
                  ? 'holnap'
                  : '$days nap';
      await HomeWidget.saveWidgetData<String>('item_${i}_name', item.name);
      await HomeWidget.saveWidgetData<String>('item_${i}_date', date);
    }
    await HomeWidget.saveWidgetData<int>('item_count', urgent.length);
    await HomeWidget.updateWidget(
      qualifiedAndroidName:
          'com.example.smartfridge.SmartFridgeWidgetProvider',
    );
  }

  void _reset() {
    _itemsSub?.cancel();
    _shoppingSub?.cancel();
    _household = null;
    _allHouseholds = [];
    _items = [];
    _shoppingItems = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _itemsSub?.cancel();
    _shoppingSub?.cancel();
    super.dispose();
  }
}
