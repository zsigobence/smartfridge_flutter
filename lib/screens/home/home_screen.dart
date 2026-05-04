import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/fridge_item.dart';
import '../../models/shopping_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/household_provider.dart';
import '../../screens/household/household_screen.dart';
import '../../screens/items/add_item_screen.dart';
import '../../screens/items/batch_add_screen.dart';
import '../../screens/items/scanner_screen.dart';
import '../../screens/shopping/shopping_list_screen.dart';
import '../../widgets/fridge_item_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final household = context.watch<HouseholdProvider>();
    if (household.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!household.hasHousehold) return const HouseholdScreen();
    return const _FridgeScreen();
  }
}

class _FridgeScreen extends StatefulWidget {
  const _FridgeScreen();

  @override
  State<_FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<_FridgeScreen> {
  String _query = '';
  bool _searchOpen = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<FridgeItem> _filter(List<FridgeItem> items) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where((i) => i.name.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _startBatchScan(BuildContext context) async {
    final barcodes = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
          builder: (_) => const ScannerScreen(batchMode: true)),
    );
    if (barcodes == null || barcodes.isEmpty || !context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => BatchAddScreen(barcodes: barcodes)),
    );
  }

  Future<void> _dismissExpired(BuildContext context) async {
    final household = context.read<HouseholdProvider>();
    final expired = household.expiredItems;
    if (expired.isEmpty) return;

    bool addToShopping = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Lejárt termékek törlése'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${expired.length} termék lejárt. Biztosan törlöd mind?'),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: addToShopping,
                onChanged: (v) => setState(() => addToShopping = v ?? false),
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
              child: const Text('Mind törlése'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    if (addToShopping) {
      for (final item in expired) {
        await household.addShoppingItem(ShoppingItem(
          id: const Uuid().v4(),
          name: item.name,
          quantity: item.quantity,
          householdId: item.householdId,
          addedAt: DateTime.now(),
        ));
      }
    }
    for (final item in expired) {
      await household.deleteItem(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final household = context.watch<HouseholdProvider>();
    final auth = context.read<AuthProvider>();
    final expiredItems = household.expiredItems;
    final urgentCount =
        expiredItems.length + household.expiringSoonItems.length;
    final shoppingCount = household.shoppingItems.length;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: 96,
          leading: _searchOpen
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.group_outlined),
                      tooltip: 'Háztartás',
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const HouseholdScreen())),
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      tooltip: 'Tömeges bevitel',
                      onPressed: () => _startBatchScan(context),
                    ),
                  ],
                ),
          title: _searchOpen
              ? TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Keresés...',
                    border: InputBorder.none,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                )
              : Text(household.household?.name ?? 'SmartFridge'),
          actions: [
            IconButton(
              icon: Icon(_searchOpen ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _searchOpen = !_searchOpen;
                  if (!_searchOpen) {
                    _query = '';
                    _searchCtrl.clear();
                  }
                });
              },
            ),
            if (!_searchOpen)
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Kijelentkezés',
                onPressed: auth.signOut,
              ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (urgentCount > 0)
                      const Icon(Icons.warning_amber_rounded,
                          size: 16, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text('Figyelj ($urgentCount)'),
                  ],
                ),
              ),
              Tab(text: 'Friss (${_filter(household.freshItems).length})'),
              Tab(text: 'Összes (${_filter(household.items).length})'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Banner lejárt termékekhez
            if (expiredItems.isNotEmpty)
              MaterialBanner(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                content: Text(
                  '${expiredItems.length} termék lejárt – ki kell dobni!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                leading: const Icon(Icons.delete_forever_outlined,
                    color: Colors.red),
                backgroundColor:
                    Colors.red.withValues(alpha: 0.08),
                actions: [
                  TextButton(
                    onPressed: () => _dismissExpired(context),
                    child: const Text('Törlés',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _ItemList(
                    items: _filter([
                      ...expiredItems,
                      ...household.expiringSoonItems,
                    ]),
                    emptyMessage: 'Nincs lejárt vagy hamarosan lejáró termék!',
                  ),
                  _ItemList(
                    items: _filter(household.freshItems),
                    emptyMessage: 'Nincs friss termék a hűtőben.',
                  ),
                  _ItemList(
                    items: _filter(household.items),
                    emptyMessage: 'A hűtő üres. Adj hozzá terméket!',
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FloatingActionButton.extended(
                heroTag: 'shoppingListBtn',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const ShoppingListScreen())),
                icon: const Icon(Icons.shopping_cart_outlined),
                label: Text('Bevásárló ($shoppingCount)'),
              ),
              FloatingActionButton.extended(
                heroTag: 'addProductBtn',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AddItemScreen())),
                icon: const Icon(Icons.add),
                label: const Text('Termék hozzáadása'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  final List<FridgeItem> items;
  final String emptyMessage;

  const _ItemList({required this.items, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(emptyMessage,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
      itemCount: items.length,
      itemBuilder: (_, i) => FridgeItemCard(item: items[i]),
    );
  }
}
