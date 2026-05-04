import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingItem {
  final String id;
  final String name;
  final int quantity;
  final String householdId;
  final DateTime addedAt;
  final bool isChecked;

  const ShoppingItem({
    required this.id,
    required this.name,
    this.quantity = 1,
    required this.householdId,
    required this.addedAt,
    this.isChecked = false,
  });

  factory ShoppingItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ShoppingItem(
      id: doc.id,
      name: data['name'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      householdId: data['householdId'] as String? ?? '',
      addedAt: data['addedAt'] is Timestamp 
          ? (data['addedAt'] as Timestamp).toDate() 
          : DateTime.now(),
      isChecked: data['isChecked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'quantity': quantity,
        'householdId': householdId,
        'addedAt': Timestamp.fromDate(addedAt),
        'isChecked': isChecked,
      };

  ShoppingItem copyWith({
    String? id,
    String? name,
    int? quantity,
    String? householdId,
    DateTime? addedAt,
    bool? isChecked,
  }) =>
      ShoppingItem(
        id: id ?? this.id,
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        householdId: householdId ?? this.householdId,
        addedAt: addedAt ?? this.addedAt,
        isChecked: isChecked ?? this.isChecked,
      );
}
