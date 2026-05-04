import 'package:flutter/material.dart';

import '../models/fridge_item.dart';

class ExpiryBadge extends StatelessWidget {
  final FridgeItem item;

  const ExpiryBadge({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.isExpired) return _badge('Lejárt!', Colors.red);
    return switch (item.daysUntilExpiry) {
      0 => _badge('Ma jár le!', Colors.orange),
      1 => _badge('Holnap jár le', Colors.orange),
      <= 3 => _badge('${item.daysUntilExpiry} nap múlva', Colors.amber.shade700),
      final d => _badge('$d nap', Colors.green),
    };
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 11),
        ),
      );
}
