import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/shopping_item.dart';
import '../../providers/household_provider.dart';

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  void _showAddDialog(BuildContext context) {
    final household = context.read<HouseholdProvider>();
    final nameCtrl = TextEditingController();
    int qty = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Tétel hozzáadása'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Termék neve',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Mennyiség:',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: qty > 1 ? () => setState(() => qty--) : null,
                    visualDensity: VisualDensity.compact,
                  ),
                  SizedBox(
                    width: 32,
                    child: Text('$qty',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => setState(() => qty++),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Mégse'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                household.addShoppingItem(ShoppingItem(
                  id: const Uuid().v4(),
                  name: name,
                  quantity: qty,
                  householdId: household.household!.id,
                  addedAt: DateTime.now(),
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Hozzáadás'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final household = context.watch<HouseholdProvider>();
    final items = household.shoppingItems;
    final hasChecked = items.any((i) => i.isChecked);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bevásárlólista'),
        actions: [
          if (hasChecked)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Bejelöltek törlése',
              onPressed: () => household.deleteCheckedShoppingItems(),
            ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_cart_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('A bevásárlólista üres.',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => _showAddDialog(context),
                    child: const Text('Tétel hozzáadása'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
              itemCount: items.length,
              itemBuilder: (_, i) => _ShoppingItemCard(item: items[i]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Tétel hozzáadása'),
      ),
    );
  }
}

class _ShoppingItemCard extends StatelessWidget {
  final ShoppingItem item;

  const _ShoppingItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final household = context.read<HouseholdProvider>();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: item.isChecked,
              onChanged: (v) => household.updateShoppingItem(
                item.copyWith(isChecked: v ?? false),
              ),
            ),
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: item.isChecked
                      ? TextDecoration.lineThrough
                      : null,
                  color: item.isChecked ? Colors.grey : null,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: item.quantity > 1
                  ? () => household.updateShoppingItem(
                        item.copyWith(quantity: item.quantity - 1),
                      )
                  : null,
            ),
            Text(
              '${item.quantity}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: () => household.updateShoppingItem(
                item.copyWith(quantity: item.quantity + 1),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: Colors.red),
              visualDensity: VisualDensity.compact,
              onPressed: () => household.deleteShoppingItem(item),
            ),
          ],
        ),
      ),
    );
  }
}
