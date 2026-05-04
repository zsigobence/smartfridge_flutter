import 'package:cloud_firestore/cloud_firestore.dart';

class Household {
  final String id;
  final String name;
  final String inviteCode;
  final List<String> members;
  final String createdBy;
  final DateTime createdAt;

  const Household({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.members,
    required this.createdBy,
    required this.createdAt,
  });

  factory Household.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Household(
      id: doc.id,
      name: data['name'] as String? ?? '',
      inviteCode: data['inviteCode'] as String? ?? '',
      members: List<String>.from(data['members'] as List? ?? []),
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'inviteCode': inviteCode,
        'members': members,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
