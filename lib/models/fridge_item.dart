import 'package:cloud_firestore/cloud_firestore.dart';

class FridgeItem {
  final String id;
  final String name;
  final String? barcode;
  final DateTime expiryDate;
  final String? imageUrl;
  final String addedBy;
  final String householdId;
  final DateTime addedAt;
  final int quantity;
  final bool isOpened;
  final DateTime? openedAt;
  final int? openedExpiryDays;

  const FridgeItem({
    required this.id,
    required this.name,
    this.barcode,
    required this.expiryDate,
    this.imageUrl,
    required this.addedBy,
    required this.householdId,
    required this.addedAt,
    this.quantity = 1,
    this.isOpened = false,
    this.openedAt,
    this.openedExpiryDays,
  });

  DateTime get effectiveExpiryDate {
    final base = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    if (isOpened && openedAt != null && openedExpiryDays != null) {
      final openedExpiry = DateTime(openedAt!.year, openedAt!.month, openedAt!.day)
          .add(Duration(days: openedExpiryDays!));
      return openedExpiry.isBefore(base) ? openedExpiry : base;
    }
    return base;
  }

  int get daysUntilExpiry {
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return effectiveExpiryDate.difference(today).inDays;
  }

  bool get isExpired => daysUntilExpiry < 0;
  bool get isExpiringSoon => !isExpired && daysUntilExpiry <= 3;

  factory FridgeItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FridgeItem(
      id: doc.id,
      name: data['name'] as String? ?? '',
      barcode: data['barcode'] as String?,
      expiryDate: data['expiryDate'] is Timestamp
          ? (data['expiryDate'] as Timestamp).toDate()
          : DateTime.now(),
      imageUrl: data['imageUrl'] as String?,
      addedBy: data['addedBy'] as String? ?? '',
      householdId: data['householdId'] as String? ?? '',
      addedAt: data['addedAt'] is Timestamp
          ? (data['addedAt'] as Timestamp).toDate()
          : DateTime.now(),
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      isOpened: data['isOpened'] as bool? ?? false,
      openedAt: data['openedAt'] is Timestamp
          ? (data['openedAt'] as Timestamp).toDate()
          : null,
      openedExpiryDays: (data['openedExpiryDays'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'barcode': barcode,
        'expiryDate': Timestamp.fromDate(expiryDate),
        'imageUrl': imageUrl,
        'addedBy': addedBy,
        'householdId': householdId,
        'addedAt': Timestamp.fromDate(addedAt),
        'quantity': quantity,
        'isOpened': isOpened,
        'openedAt': openedAt != null ? Timestamp.fromDate(openedAt!) : null,
        'openedExpiryDays': openedExpiryDays,
      };

  FridgeItem copyWith({
    String? id,
    String? name,
    String? barcode,
    DateTime? expiryDate,
    String? imageUrl,
    String? addedBy,
    String? householdId,
    DateTime? addedAt,
    int? quantity,
    bool? isOpened,
    DateTime? openedAt,
    int? openedExpiryDays,
    bool clearOpenedAt = false,
    bool clearOpenedExpiryDays = false,
  }) =>
      FridgeItem(
        id: id ?? this.id,
        name: name ?? this.name,
        barcode: barcode ?? this.barcode,
        expiryDate: expiryDate ?? this.expiryDate,
        imageUrl: imageUrl ?? this.imageUrl,
        addedBy: addedBy ?? this.addedBy,
        householdId: householdId ?? this.householdId,
        addedAt: addedAt ?? this.addedAt,
        quantity: quantity ?? this.quantity,
        isOpened: isOpened ?? this.isOpened,
        openedAt: clearOpenedAt ? null : (openedAt ?? this.openedAt),
        openedExpiryDays: clearOpenedExpiryDays
            ? null
            : (openedExpiryDays ?? this.openedExpiryDays),
      );
}
