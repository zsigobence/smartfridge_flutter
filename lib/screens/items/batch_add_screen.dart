import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/fridge_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/household_provider.dart';
import '../../services/local_image_cache_service.dart';
import '../../services/open_food_facts_service.dart';
import 'add_item_screen.dart' show ItemImage;

class BatchAddScreen extends StatefulWidget {
  final List<String> barcodes;

  const BatchAddScreen({super.key, required this.barcodes});

  @override
  State<BatchAddScreen> createState() => _BatchAddScreenState();
}

class _BatchAddScreenState extends State<BatchAddScreen> {
  final _offService = OpenFoodFactsService();
  final _picker = ImagePicker();

  int _currentIndex = 0;
  bool _initialLoading = true;

  late List<_ItemData> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.barcodes.map((b) => _ItemData(barcode: b)).toList();
    _lookupAll();
  }

  Future<void> _lookupAll() async {
    final household = context.read<HouseholdProvider>();

    for (int i = 0; i < _items.length; i++) {
      final barcode = _items[i].barcode;

      final existing = await household.getItemByBarcode(barcode);
      if (existing != null) {
        _items[i].nameCtrl.text = existing.name;
        // Előnyben részesítjük a helyi gyorsítótárat az elmentett URL felett
        final cached = await LocalImageCacheService.getImagePath(barcode) ??
            await LocalImageCacheService.getImagePath(existing.name);
        _items[i].imagePath = cached ?? existing.imageUrl;
        continue;
      }

      final info = await _offService.lookupBarcode(barcode);
      final cached = await LocalImageCacheService.getImagePath(barcode);
      if (info != null) {
        _items[i].nameCtrl.text = info.name;
        final cachedByName =
            await LocalImageCacheService.getImagePath(info.name);
        _items[i].imagePath = cached ?? cachedByName ?? info.imageUrl;
      } else if (cached != null) {
        _items[i].imagePath = cached;
      }
    }

    if (mounted) setState(() => _initialLoading = false);
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galéria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked == null || !mounted) return;

    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(dir.path, 'item_images'));
    if (!imagesDir.existsSync()) imagesDir.createSync(recursive: true);

    final ext = p.extension(picked.path).isNotEmpty
        ? p.extension(picked.path)
        : '.jpg';
    final localPath = p.join(imagesDir.path, '${const Uuid().v4()}$ext');
    await File(picked.path).copy(localPath);

    setState(() => _items[_currentIndex].imagePath = localPath);
  }

  Future<void> _pickDate() async {
    final item = _items[_currentIndex];
    final picked = await showDatePicker(
      context: context,
      initialDate:
          item.expiryDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'Lejárati dátum kiválasztása',
    );
    if (picked != null) setState(() => item.expiryDate = picked);
  }

  Future<void> _saveCurrentAndNext() async {
    final item = _items[_currentIndex];

    if (item.nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add meg a termék nevét!')),
      );
      return;
    }
    if (item.expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add meg a lejárati dátumot!')),
      );
      return;
    }

    final household = context.read<HouseholdProvider>();
    final auth = context.read<AuthProvider>();
    final name = item.nameCtrl.text.trim();

    // Kép-gyorsítótár mentése névhez és vonalkódhoz
    if (item.imagePath != null) {
      await LocalImageCacheService.saveImageMapping(name, item.imagePath!);
      await LocalImageCacheService.saveImageMapping(
          item.barcode, item.imagePath!);
    }

    await household.addItem(FridgeItem(
      id: const Uuid().v4(),
      name: name,
      barcode: item.barcode,
      expiryDate: item.expiryDate!,
      imageUrl: item.imagePath,
      addedBy: auth.user!.uid,
      householdId: household.household!.id,
      addedAt: DateTime.now(),
      quantity: item.quantity,
    ));

    final isLast = _currentIndex == _items.length - 1;
    if (isLast) {
      if (mounted) Navigator.pop(context);
    } else {
      setState(() => _currentIndex++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _initialLoading
              ? 'Adatok betöltése...'
              : 'Termék ${_currentIndex + 1} / $total',
        ),
        bottom: _initialLoading
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / total,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
      ),
      body: _initialLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Termékadatok betöltése...'),
                ],
              ),
            )
          : _ItemForm(
              key: ValueKey(_currentIndex),
              data: _items[_currentIndex],
              onPickDate: _pickDate,
              onPickImage: _pickImage,
              onQuantityChanged: (v) =>
                  setState(() => _items[_currentIndex].quantity = v),
            ),
      floatingActionButton: _initialLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: _saveCurrentAndNext,
              icon: Icon(
                _currentIndex < total - 1 ? Icons.arrow_forward : Icons.check,
              ),
              label: Text(
                _currentIndex < total - 1
                    ? 'Mentés és következő'
                    : 'Mentés és kész',
              ),
            ),
    );
  }
}

class _ItemData {
  final String barcode;
  final TextEditingController nameCtrl = TextEditingController();
  String? imagePath;
  DateTime? expiryDate;
  int quantity = 1;

  _ItemData({required this.barcode});

  void dispose() => nameCtrl.dispose();
}

class _ItemForm extends StatelessWidget {
  final _ItemData data;
  final VoidCallback onPickDate;
  final VoidCallback onPickImage;
  final ValueChanged<int> onQuantityChanged;

  const _ItemForm({
    super.key,
    required this.data,
    required this.onPickDate,
    required this.onPickImage,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vonalkód chip
          Chip(
            avatar: const Icon(Icons.qr_code, size: 18),
            label: Text(data.barcode,
                style: const TextStyle(fontFamily: 'monospace')),
          ),
          const SizedBox(height: 12),

          // Kép előnézet + választó
          GestureDetector(
            onTap: onPickImage,
            child: data.imagePath != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ItemImage(
                          imagePath: data.imagePath!,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.black54,
                          child: const Icon(Icons.edit,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  )
                : Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outline),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 36),
                        SizedBox(height: 6),
                        Text('Kép hozzáadása'),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),

          // Termék neve
          TextFormField(
            controller: data.nameCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Termék neve *',
              prefixIcon: Icon(Icons.label_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Darabszám
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Darabszám',
              prefixIcon: Icon(Icons.inventory_2_outlined),
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: data.quantity > 1
                      ? () => onQuantityChanged(data.quantity - 1)
                      : null,
                  visualDensity: VisualDensity.compact,
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${data.quantity}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => onQuantityChanged(data.quantity + 1),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Lejárati dátum
          InkWell(
            onTap: onPickDate,
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Lejárati dátum *',
                prefixIcon: Icon(Icons.calendar_today),
                border: OutlineInputBorder(),
              ),
              child: Text(
                data.expiryDate != null
                    ? DateFormat('yyyy. MM. dd.').format(data.expiryDate!)
                    : 'Válassz dátumot',
                style: TextStyle(
                  color: data.expiryDate != null ? null : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 88),
        ],
      ),
    );
  }
}
