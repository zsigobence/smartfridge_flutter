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
import 'scanner_screen.dart';

class AddItemScreen extends StatefulWidget {
  final FridgeItem? existingItem;

  const AddItemScreen({super.key, this.existingItem});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _offService = OpenFoodFactsService();
  final _picker = ImagePicker();

  String? _barcode;
  DateTime? _expiryDate;
  String? _imagePath;
  int _quantity = 1;
  bool _loading = false;
  bool _lookingUp = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      final item = widget.existingItem!;
      _nameCtrl.text = item.name;
      _barcode = item.barcode;
      _expiryDate = item.expiryDate;
      _imagePath = item.imageUrl;
      _quantity = item.quantity;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
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

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    // Belső tárolóba másoljuk, hogy ne függjünk a galéria elérési útjától
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(dir.path, 'item_images'));
    if (!imagesDir.existsSync()) imagesDir.createSync(recursive: true);

    final ext = p.extension(picked.path).isNotEmpty
        ? p.extension(picked.path)
        : '.jpg';
    final localPath =
        p.join(imagesDir.path, '${const Uuid().v4()}$ext');
    await File(picked.path).copy(localPath);

    setState(() => _imagePath = localPath);
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (code == null || !mounted) return;

    setState(() {
      _barcode = code;
      _lookingUp = true;
    });

    final existingItem =
        await context.read<HouseholdProvider>().getItemByBarcode(code);
    if (!mounted) return;

    if (existingItem != null) {
      _nameCtrl.text = existingItem.name;
      setState(() {
        _imagePath = existingItem.imageUrl;
        _lookingUp = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ismert termék – adatok automatikusan kitöltve!'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    final info = await _offService.lookupBarcode(code);
    final cachedImagePath = await LocalImageCacheService.getImagePath(code);
    if (!mounted) return;

    setState(() {
      _lookingUp = false;
      if (info != null) {
        _nameCtrl.text = info.name;
        // Open Food Facts hálózati URL-t tárolunk (nincs lokális másolat), kivéve ha van helyi gyorsítótárazott
        _imagePath = cachedImagePath ?? info.imageUrl;
      } else if (cachedImagePath != null) {
        _imagePath = cachedImagePath;
      }
    });

    if (info != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Termék adatok betöltve!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Termék nem található – kérjük töltsd ki kézzel.')),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _expiryDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'Lejárati dátum kiválasztása',
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _onNameChanged(String value) async {
    if (_imagePath != null || value.trim().isEmpty) return;

    final cachedPath = await LocalImageCacheService.getImagePath(value);
    if (!mounted) return;

    if (cachedPath != null && _imagePath == null) {
      setState(() {
        _imagePath = cachedPath;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Korábbi kép automatikusan betöltve!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kérjük add meg a lejárati dátumot!')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final household = context.read<HouseholdProvider>();
      final auth = context.read<AuthProvider>();

      if (widget.existingItem != null) {
        await household.updateItem(widget.existingItem!.copyWith(
          name: _nameCtrl.text.trim(),
          barcode: _barcode,
          expiryDate: _expiryDate,
          imageUrl: _imagePath,
          quantity: _quantity,
        ));
      } else {
        await household.addItem(FridgeItem(
          id: const Uuid().v4(),
          name: _nameCtrl.text.trim(),
          barcode: _barcode,
          expiryDate: _expiryDate!,
          imageUrl: _imagePath,
          addedBy: auth.user!.uid,
          householdId: household.household!.id,
          addedAt: DateTime.now(),
          quantity: _quantity,
        ));
      }

      if (_imagePath != null && _imagePath!.isNotEmpty) {
        if (_barcode != null && _barcode!.isNotEmpty) {
          await LocalImageCacheService.saveImageMapping(_barcode!, _imagePath!);
        }
        if (_nameCtrl.text.trim().isNotEmpty) {
          await LocalImageCacheService.saveImageMapping(_nameCtrl.text, _imagePath!);
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingItem != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Termék szerkesztése' : 'Termék hozzáadása'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BarcodeSection(
                barcode: _barcode,
                isLookingUp: _lookingUp,
                onScan: _scanBarcode,
              ),
              const SizedBox(height: 12),
              _ImagePickerSection(
                imagePath: _imagePath,
                onPick: _pickImage,
                onRemove: () => setState(() => _imagePath = null),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                onChanged: _onNameChanged,
                decoration: const InputDecoration(
                  labelText: 'Termék neve *',
                  prefixIcon: Icon(Icons.label_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v!.trim().isNotEmpty ? null : 'Kötelező mező',
              ),
              const SizedBox(height: 16),
              _QuantityStepper(
                quantity: _quantity,
                onChanged: (v) => setState(() => _quantity = v),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Lejárati dátum *',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _expiryDate != null
                        ? DateFormat('yyyy. MM. dd.').format(_expiryDate!)
                        : 'Válassz dátumot',
                    style: TextStyle(
                      color: _expiryDate != null ? null : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isEditing ? 'Mentés' : 'Hozzáadás'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePickerSection extends StatelessWidget {
  final String? imagePath;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ImagePickerSection({
    required this.imagePath,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kép', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ItemImage(
                  imagePath: imagePath!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: onPick,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_library_outlined, size: 18),
                      const SizedBox(width: 4),
                      Text(imagePath == null
                          ? 'Kép kiválasztása'
                          : 'Kép cseréje'),
                    ],
                  ),
                ),
                if (imagePath != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Kép eltávolítása',
                    onPressed: onRemove,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BarcodeSection extends StatelessWidget {
  final String? barcode;
  final bool isLookingUp;
  final VoidCallback onScan;

  const _BarcodeSection({
    required this.barcode,
    required this.isLookingUp,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vonalkód', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: barcode != null
                      ? Text(
                          'Beolvasva: $barcode',
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w500),
                        )
                      : const Text('Nincs vonalkód',
                          style: TextStyle(color: Colors.grey)),
                ),
                if (isLookingUp)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                FilledButton.tonal(
                  onPressed: onScan,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_scanner, size: 18),
                      SizedBox(width: 4),
                      Text('Szkennelés'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;

  const _QuantityStepper({required this.quantity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Darabszám',
        prefixIcon: Icon(Icons.inventory_2_outlined),
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => onChanged(quantity + 1),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Lokális fájlútvonalat és hálózati URL-t egyaránt kezel.
class ItemImage extends StatelessWidget {
  final String imagePath;
  final double? height;
  final double? width;
  final BoxFit fit;

  const ItemImage({
    super.key,
    required this.imagePath,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  bool get _isNetwork =>
      imagePath.startsWith('http://') || imagePath.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    if (_isNetwork) {
      return Image.network(
        imagePath,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    final file = File(imagePath);
    if (!file.existsSync()) return _placeholder();
    return Image.file(
      file,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder() => SizedBox(
        height: height,
        width: width,
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined,
              size: 32, color: Colors.grey),
        ),
      );
}
