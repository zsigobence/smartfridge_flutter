import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/fridge_item.dart';
import '../models/household.dart';
import '../models/shopping_item.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  static const _households = 'households';
  static const _items = 'items';
  static const _users = 'users';
  static const _shoppingItems = 'shoppingItems';

  Future<void> saveUserData(
      String uid, String email, String username) async {
    await _db.collection(_users).doc(uid).set({
      'email': email,
      'username': username.toLowerCase(),
    }, SetOptions(merge: true));
  }

  Future<String?> getEmailByUsername(String username) async {
    final snap = await _db
        .collection(_users)
        .where('username', isEqualTo: username.toLowerCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data()['email'] as String?;
  }

  Future<bool> isUsernameTaken(String username) async {
    final snap = await _db
        .collection(_users)
        .where('username', isEqualTo: username.toLowerCase())
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Visszaadja a felhasználó összes háztartás ID-ját.
  /// Régi formátum (egyszeres householdId) automatikusan migrálódik.
  Future<List<String>> getUserHouseholdIds(String userId) async {
    final doc = await _db.collection(_users).doc(userId).get();
    final data = doc.data();
    if (data == null) return [];

    // Migráció: régi egyszeres householdId → householdIds tömb
    if (data['householdIds'] == null && data['householdId'] != null) {
      final oldId = data['householdId'] as String;
      await _db.collection(_users).doc(userId).set({
        'householdIds': [oldId],
      }, SetOptions(merge: true));
      return [oldId];
    }

    return List<String>.from(data['householdIds'] as List? ?? []);
  }

  Future<Household> createHousehold(String name, String userId) async {
    final inviteCode =
        'FRIDGE-${const Uuid().v4().substring(0, 6).toUpperCase()}';
    final ref = await _db.collection(_households).add({
      'name': name,
      'inviteCode': inviteCode,
      'members': [userId],
      'createdBy': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _db.collection(_users).doc(userId).set({
      'householdIds': FieldValue.arrayUnion([ref.id]),
    }, SetOptions(merge: true));
    final doc = await ref.get();
    return Household.fromFirestore(doc);
  }

  Future<Household?> joinHousehold(String inviteCode, String userId) async {
    final query = await _db
        .collection(_households)
        .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;

    // Már tag?
    final members = List<String>.from(doc.data()['members'] as List? ?? []);
    if (!members.contains(userId)) {
      await doc.reference.update({
        'members': FieldValue.arrayUnion([userId]),
      });
    }
    await _db.collection(_users).doc(userId).set({
      'householdIds': FieldValue.arrayUnion([doc.id]),
    }, SetOptions(merge: true));
    final updated = await doc.reference.get();
    return Household.fromFirestore(updated);
  }

  Future<void> leaveHousehold(String householdId, String userId) async {
    await _db.collection(_households).doc(householdId).update({
      'members': FieldValue.arrayRemove([userId]),
    });
    await _db.collection(_users).doc(userId).update({
      'householdIds': FieldValue.arrayRemove([householdId]),
    });
  }

  Future<Household?> getHousehold(String householdId) async {
    final doc = await _db.collection(_households).doc(householdId).get();
    if (!doc.exists) return null;
    return Household.fromFirestore(doc);
  }

  Future<List<Household>> getHouseholds(List<String> ids) async {
    final result = <Household>[];
    for (final id in ids) {
      final h = await getHousehold(id);
      if (h != null) result.add(h);
    }
    return result;
  }

  Stream<List<FridgeItem>> itemsStream(String householdId) {
    return _db
        .collection(_households)
        .doc(householdId)
        .collection(_items)
        .orderBy('expiryDate')
        .snapshots()
        .map((snap) => snap.docs.map(FridgeItem.fromFirestore).toList());
  }

  Future<void> addItem(FridgeItem item) async {
    await _db
        .collection(_households)
        .doc(item.householdId)
        .collection(_items)
        .doc(item.id)
        .set(item.toFirestore());
  }

  Future<void> updateItem(FridgeItem item) async {
    await _db
        .collection(_households)
        .doc(item.householdId)
        .collection(_items)
        .doc(item.id)
        .update(item.toFirestore());
  }

  Future<void> deleteItem(FridgeItem item) async {
    await _db
        .collection(_households)
        .doc(item.householdId)
        .collection(_items)
        .doc(item.id)
        .delete();
  }

  Future<FridgeItem?> getItemByBarcode(
      String householdId, String barcode) async {
    final snap = await _db
        .collection(_households)
        .doc(householdId)
        .collection(_items)
        .where('barcode', isEqualTo: barcode)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return FridgeItem.fromFirestore(snap.docs.first);
  }

  // ── Bevásárlólista ──────────────────────────────────────────────

  Stream<List<ShoppingItem>> shoppingItemsStream(String householdId) {
    return _db
        .collection(_households)
        .doc(householdId)
        .collection(_shoppingItems)
        .orderBy('addedAt')
        .snapshots()
        .map((snap) => snap.docs.map(ShoppingItem.fromFirestore).toList());
  }

  Future<void> addShoppingItem(ShoppingItem item) async {
    await _db
        .collection(_households)
        .doc(item.householdId)
        .collection(_shoppingItems)
        .doc(item.id)
        .set(item.toFirestore());
  }

  Future<void> updateShoppingItem(ShoppingItem item) async {
    await _db
        .collection(_households)
        .doc(item.householdId)
        .collection(_shoppingItems)
        .doc(item.id)
        .update(item.toFirestore());
  }

  Future<void> deleteShoppingItem(ShoppingItem item) async {
    await _db
        .collection(_households)
        .doc(item.householdId)
        .collection(_shoppingItems)
        .doc(item.id)
        .delete();
  }

  Future<void> deleteCheckedShoppingItems(String householdId) async {
    final snap = await _db
        .collection(_households)
        .doc(householdId)
        .collection(_shoppingItems)
        .where('isChecked', isEqualTo: true)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
