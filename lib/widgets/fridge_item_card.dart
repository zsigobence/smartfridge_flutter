import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/fridge_item.dart';
import '../models/shopping_item.dart';
import '../providers/household_provider.dart';
import '../screens/items/add_item_screen.dart' show AddItemScreen, ItemImage;
import 'expiry_badge.dart';

class FridgeItemCard extends StatefulWidget {
  final FridgeItem item;

  const FridgeItemCard({super.key, required this.item});

  @override
  State<FridgeItemCard> createState() => _FridgeItemCardState();
}

class _FridgeItemCardState extends State<FridgeItemCard> {
  late int _localQuantity;
  bool _pendingWrite = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _localQuantity = widget.item.quantity;
  }

  @override
  void didUpdateWidget(FridgeItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ha nincs függőben lévő írás, fogadjuk el a Firestore-ból érkező frissítést
    if (!_pendingWrite && widget.item.quantity != _localQuantity) {
      setState(() => _localQuantity = widget.item.quantity);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _changeQuantity(int newQty) {
    setState(() {
      _localQuantity = newQty;
      _pendingWrite = true;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _pendingWrite = false);
      context.read<HouseholdProvider>().updateItem(
            widget.item.copyWith(quantity: _localQuantity),
          );
    });
  }

  Future<void> _showOpenedDialog(BuildContext context) async {
    final item = widget.item;
    bool isOpened = item.isOpened;
    int days = item.openedExpiryDays ?? 3;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Felbontás'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: const Text('Felbontva'),
                value: isOpened,
                onChanged: (v) => setDialogState(() => isOpened = v),
                contentPadding: EdgeInsets.zero,
              ),
              if (isOpened) ...[
                const SizedBox(height: 8),
                const Text('Hány napig jó felbontás után?'),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: days > 1
                          ? () => setDialogState(() => days--)
                          : null,
                    ),
                    Text(
                      '$days nap',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setDialogState(() => days++),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Mégse'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (!mounted) return;
                context.read<HouseholdProvider>().updateItem(
                      isOpened
                          ? item.copyWith(
                              isOpened: true,
                              openedAt: item.openedAt ?? DateTime.now(),
                              openedExpiryDays: days,
                            )
                          : item.copyWith(
                              isOpened: false,
                              clearOpenedAt: true,
                              clearOpenedExpiryDays: true,
                            ),
                    );
              },
              child: const Text('Mentés'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    bool addToShopping = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Termék törlése'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Biztosan törlöd: ${widget.item.name}?'),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: addToShopping,
                onChanged: (v) =>
                    setDialogState(() => addToShopping = v ?? false),
                title: const Text('Hozzáadom a bevásárlólistához'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Mégse'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Törlés'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      final household = context.read<HouseholdProvider>();
      if (addToShopping) {
        await household.addShoppingItem(ShoppingItem(
          id: const Uuid().v4(),
          name: widget.item.name,
          quantity: widget.item.quantity,
          householdId: widget.item.householdId,
          addedAt: DateTime.now(),
        ));
      }
      await household.deleteItem(widget.item);
    }
  }

  Widget _swipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) =>
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _showOpenedDialog(context);
        } else {
          await _confirmDelete(context);
        }
        return false;
      },
      background: _swipeBackground(
        alignment: Alignment.centerLeft,
        color: Colors.orange.shade600,
        icon: item.isOpened ? Icons.lock_outline : Icons.lock_open,
        label: item.isOpened ? 'Visszazárás' : 'Felbontás',
      ),
      secondaryBackground: _swipeBackground(
        alignment: Alignment.centerRight,
        color: Colors.red.shade600,
        icon: Icons.delete_outline,
        label: 'Törlés',
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Kép
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.imageUrl != null
                    ? ItemImage(
                        imagePath: item.imageUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 56,
                        height: 56,
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.fastfood_outlined,
                            color: Colors.grey),
                      ),
              ),
              const SizedBox(width: 12),
              // Szöveg
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lejár: ${DateFormat('yyyy. MM. dd.').format(item.expiryDate)}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ExpiryBadge(item: item),
                        if (item.isOpened) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.lock_open,
                              size: 13, color: Colors.orange),
                          const SizedBox(width: 2),
                          const Text('Felbontva',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.orange)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Darabszám stepper (debounced Firestore write)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _changeQuantity(_localQuantity + 1),
                  ),
                  Text(
                    '$_localQuantity',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: _localQuantity > 1
                        ? () => _changeQuantity(_localQuantity - 1)
                        : null,
                  ),
                ],
              ),
              // Menü
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AddItemScreen(existingItem: item)),
                    );
                  } else if (v == 'delete') {
                    _confirmDelete(context);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 8),
                      Text('Szerkesztés'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Törlés', style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
