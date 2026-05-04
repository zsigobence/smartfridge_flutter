import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/household.dart';
import '../../providers/auth_provider.dart';
import '../../providers/household_provider.dart';
import '../../providers/theme_provider.dart';
import '../items/scanner_screen.dart';

class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  final _createNameCtrl = TextEditingController();
  final _joinCodeCtrl = TextEditingController();
  bool _loading = false;
  bool _showAddForm = false;

  @override
  void dispose() {
    _createNameCtrl.dispose();
    _joinCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _createHousehold() async {
    if (_createNameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final provider = context.read<HouseholdProvider>();
    final success =
        await provider.createHousehold(_createNameCtrl.text.trim());
    if (mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(provider.error ?? 'Hiba'),
            backgroundColor: Colors.red),
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _joinHousehold() async {
    final code = _joinCodeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _loading = true);
    final provider = context.read<HouseholdProvider>();
    final success = await provider.joinHousehold(code);
    if (mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(provider.error ?? 'Érvénytelen kód'),
            backgroundColor: Colors.red),
      );
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _showAddForm = false;
        _joinCodeCtrl.clear();
        _createNameCtrl.clear();
      });
    }
  }

  Future<void> _scanQrToJoin() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (result == null || !mounted) return;

    if (result.startsWith('FRIDGE-')) {
      setState(() {
        _joinCodeCtrl.text = result;
        _loading = true;
      });
      final provider = context.read<HouseholdProvider>();
      final success = await provider.joinHousehold(result);
      if (mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(provider.error ?? 'Érvénytelen kód'),
              backgroundColor: Colors.red),
        );
      }
      if (mounted) setState(() => _loading = false);
    } else {
      _joinCodeCtrl.text = result;
    }
  }

  Widget _buildSetupBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.home_outlined, size: 72, color: Color(0xFF2ECC71)),
          const SizedBox(height: 16),
          Text(
            'Csatlakozz egy háztartáshoz',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Új háztartás létrehozása',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _createNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Háztartás neve',
                      border: OutlineInputBorder(),
                      hintText: 'pl. Otthonunk',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _createHousehold,
                      child: const Text('Létrehozás'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Row(children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('VAGY'),
            ),
            Expanded(child: Divider()),
          ]),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Csatlakozás meghívó kóddal',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _joinCodeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Meghívó kód',
                      border: OutlineInputBorder(),
                      hintText: 'FRIDGE-XXXXXX',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: _loading ? null : _joinHousehold,
                          child: const Text('Csatlakozás'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _loading ? null : _scanQrToJoin,
                        icon: const Icon(Icons.qr_code_scanner),
                        tooltip: 'QR kód beolvasása',
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .secondaryContainer,
                          foregroundColor: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final household = context.watch<HouseholdProvider>();
    final auth = context.read<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(household.hasHousehold ? 'Háztartás' : 'Háztartás beállítása'),
        actions: [
          if (household.hasHousehold)
            Consumer<ThemeProvider>(
              builder: (_, theme, _) => IconButton(
                icon: Icon(theme.isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined),
                tooltip: theme.isDark ? 'Világos mód' : 'Sötét mód',
                onPressed: theme.toggle,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Kijelentkezés',
            onPressed: auth.signOut,
          ),
        ],
      ),
      body: household.hasHousehold
          ? _HouseholdInfoBody(
              onShowAddForm: () => setState(() => _showAddForm = true),
              showAddForm: _showAddForm,
              onHideAddForm: () => setState(() {
                _showAddForm = false;
                _createNameCtrl.clear();
                _joinCodeCtrl.clear();
              }),
              createNameCtrl: _createNameCtrl,
              joinCodeCtrl: _joinCodeCtrl,
              loading: _loading,
              onCreate: _createHousehold,
              onJoin: _joinHousehold,
              onScanQr: _scanQrToJoin,
            )
          : _buildSetupBody(),
    );
  }
}

// ── Info nézet (van háztartás) ────────────────────────────────────

class _HouseholdInfoBody extends StatelessWidget {
  final bool showAddForm;
  final VoidCallback onShowAddForm;
  final VoidCallback onHideAddForm;
  final TextEditingController createNameCtrl;
  final TextEditingController joinCodeCtrl;
  final bool loading;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final VoidCallback onScanQr;

  const _HouseholdInfoBody({
    required this.showAddForm,
    required this.onShowAddForm,
    required this.onHideAddForm,
    required this.createNameCtrl,
    required this.joinCodeCtrl,
    required this.loading,
    required this.onCreate,
    required this.onJoin,
    required this.onScanQr,
  });

  Future<void> _confirmLeave(BuildContext context) async {
    final household = context.read<HouseholdProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kilépés a háztartásból'),
        content: Text(
          'Biztosan ki szeretnél lépni a(z) '
          '"${household.household!.name}" háztartásból? '
          'A hűtőd tartalma megmarad.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Kilépés'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final hasOther = household.allHouseholds.length > 1;
      if (!hasOther) Navigator.of(context).pop();
      household.leaveHousehold();
    }
  }

  @override
  Widget build(BuildContext context) {
    final household = context.watch<HouseholdProvider>();
    final active = household.household!;
    final code = active.inviteCode;
    final all = household.allHouseholds;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Aktív háztartás neve ──
          Text(
            active.name,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),

          // ── Háztartás váltó (csak ha több van) ──
          if (all.length > 1) ...[
            const SizedBox(height: 16),
            Text('Háztartásaim',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Colors.grey)),
            const SizedBox(height: 8),
            ...all.map((h) => _HouseholdTile(
                  household: h,
                  isActive: h.id == active.id,
                  onSwitch: () =>
                      context.read<HouseholdProvider>().switchHousehold(h),
                )),
          ],

          const SizedBox(height: 24),

          // ── Meghívó kód ──
          Text('Meghívó kód',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      code,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2ECC71),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Másolás',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kód másolva!')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    QrImageView(
                      data: code,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mutasd ezt a képernyőt a másik félnek',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Tagok & statisztika ──
          Text('Tagok (${active.members.length})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.group_outlined,
                  color: Color(0xFF2ECC71)),
              title: Text('${active.members.length} tag a háztartásban'),
              subtitle: const Text('Valós idejű szinkron aktív'),
              trailing: const Icon(Icons.sync, color: Colors.green),
            ),
          ),
          const SizedBox(height: 16),
          _StatRow(
            expiredCount: household.expiredItems.length,
            expiringSoonCount: household.expiringSoonItems.length,
            freshCount: household.freshItems.length,
          ),

          const SizedBox(height: 32),

          // ── Háztartás hozzáadása ──
          if (!showAddForm)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onShowAddForm,
                icon: const Icon(Icons.add_home_outlined),
                label: const Text('Háztartás hozzáadása'),
              ),
            )
          else
            _AddHouseholdForm(
              createNameCtrl: createNameCtrl,
              joinCodeCtrl: joinCodeCtrl,
              loading: loading,
              onCreate: onCreate,
              onJoin: onJoin,
              onScanQr: onScanQr,
              onCancel: onHideAddForm,
            ),

          const SizedBox(height: 12),

          // ── Kilépés ──
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmLeave(context),
              icon: const Icon(Icons.exit_to_app, color: Colors.red),
              label: const Text('Kilépés a háztartásból',
                  style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _HouseholdTile extends StatelessWidget {
  final Household household;
  final bool isActive;
  final VoidCallback onSwitch;

  const _HouseholdTile({
    required this.household,
    required this.isActive,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: isActive
          ? const Color(0xFF2ECC71).withValues(alpha: 0.1)
          : null,
      child: ListTile(
        leading: Icon(
          Icons.home_outlined,
          color: isActive ? const Color(0xFF2ECC71) : null,
        ),
        title: Text(
          household.name,
          style: isActive
              ? const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF2ECC71))
              : null,
        ),
        subtitle: Text('${household.members.length} tag'),
        trailing: isActive
            ? const Chip(
                label: Text('Aktív'),
                visualDensity: VisualDensity.compact,
              )
            : FilledButton.tonal(
                onPressed: onSwitch,
                child: const Text('Váltás'),
              ),
      ),
    );
  }
}

class _AddHouseholdForm extends StatelessWidget {
  final TextEditingController createNameCtrl;
  final TextEditingController joinCodeCtrl;
  final bool loading;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final VoidCallback onScanQr;
  final VoidCallback onCancel;

  const _AddHouseholdForm({
    required this.createNameCtrl,
    required this.joinCodeCtrl,
    required this.loading,
    required this.onCreate,
    required this.onJoin,
    required this.onScanQr,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Háztartás hozzáadása',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onCancel,
                    visualDensity: VisualDensity.compact),
              ],
            ),
            const Divider(),
            TextField(
              controller: createNameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Új háztartás neve',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: loading ? null : onCreate,
                child: const Text('Létrehozás'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(child: Divider()),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('VAGY')),
                Expanded(child: Divider()),
              ]),
            ),
            TextField(
              controller: joinCodeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Meghívó kód',
                border: OutlineInputBorder(),
                hintText: 'FRIDGE-XXXXXX',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: loading ? null : onJoin,
                    child: const Text('Csatlakozás'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: loading ? null : onScanQr,
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'QR kód beolvasása',
                  style: IconButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.secondaryContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onSecondaryContainer,
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

// ── Stat sor ────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final int expiredCount;
  final int expiringSoonCount;
  final int freshCount;

  const _StatRow({
    required this.expiredCount,
    required this.expiringSoonCount,
    required this.freshCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(label: 'Lejárt', count: expiredCount, color: Colors.red),
        const SizedBox(width: 8),
        _StatCard(
            label: 'Lejáró', count: expiringSoonCount, color: Colors.orange),
        const SizedBox(width: 8),
        _StatCard(label: 'Friss', count: freshCount, color: Colors.green),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatCard(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        color: color.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: color),
              ),
              Text(label, style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
