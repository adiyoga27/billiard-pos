import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/billing_calculator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/form_page.dart';
import '../../auth/providers/auth_providers.dart';
import '../../settings/domain/settings_models.dart';

import '../domain/package_models.dart';
import '../domain/table_models.dart';
import '../providers/tables_providers.dart';

enum _StartMode { bebas, durasiTetap, paketFlat, paketTarifKhusus }

/// Halaman mulai sesi (bukan modal — responsive penuh):
/// - Tanpa batas waktu (bebas)
/// - Set durasi (target waktu selesai + peringatan otomatis)
/// - Paket main billiard (durasi flat / tarif khusus)
class StartSessionScreen extends ConsumerStatefulWidget {
  final BillTable table;
  final AppSettings settings;

  const StartSessionScreen({super.key, required this.table, required this.settings});

  @override
  ConsumerState<StartSessionScreen> createState() => _StartSessionScreenState();
}

class _StartSessionScreenState extends ConsumerState<StartSessionScreen> {
  _StartMode _mode = _StartMode.bebas;
  int _targetHours = 1;
  int _targetMinutes = 0;
  PlayPackage? _selectedPackage;
  bool _saving = false;
  String? _error;
  List<PlayPackage> _packages = const [];

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    final packages = await ref.read(applicablePackagesProvider(widget.table.id).future);
    if (mounted) setState(() => _packages = packages);
  }

  Future<void> _start() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      switch (_mode) {
        case _StartMode.bebas:
          await ref.read(tablesRepositoryProvider).startSession(
                table: widget.table,
                kasir: user,
                mode: SessionMode.bebas,
              );
        case _StartMode.durasiTetap:
          await ref.read(tablesRepositoryProvider).startSession(
                table: widget.table,
                kasir: user,
                mode: SessionMode.durasiTetap,
                targetDurationMinutes: _targetHours * 60 + _targetMinutes,
              );
        case _StartMode.paketFlat:
        case _StartMode.paketTarifKhusus:
          await ref.read(tablesRepositoryProvider).startSession(
                table: widget.table,
                kasir: user,
                mode: _selectedPackage!.tipe == PackageType.durasiFlat
                    ? SessionMode.durasiTetap
                    : SessionMode.bebas,
                paket: _selectedPackage,
                paketNama: _selectedPackage!.namaPaket,
              );
      }
      if (mounted) context.pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Mulai Sesi — ${widget.table.namaMeja}',
      saving: _saving,
      onSave: _start,
      saveLabel: _mode == _StartMode.bebas || _mode == _StartMode.durasiTetap
          ? 'Mulai Sesi'
          : 'Mulai dengan ${_selectedPackage?.namaPaket}',
      hint: '${formatRupiah(widget.table.tarifPerJam)} / jam • pembulatan ${widget.table.metodePembulatan.label.toLowerCase()}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ModeCard(
            selected: _mode == _StartMode.bebas,
            icon: Icons.all_inclusive_rounded,
            title: 'Tanpa batas waktu',
            subtitle: 'Sesi berjalan bebas, biaya dihitung dari durasi saat "Selesai"',
            onTap: () => setState(() => _mode = _StartMode.bebas),
          ),
          const SizedBox(height: 10),
          _ModeCard(
            selected: _mode == _StartMode.durasiTetap,
            icon: Icons.timer_outlined,
            title: 'Set durasi',
            subtitle:
                'Target waktu selesai + peringatan ${widget.settings.ambangPeringatanMenit} menit sebelum habis',
            onTap: () => setState(() => _mode = _StartMode.durasiTetap),
          ),
          if (_mode == _StartMode.durasiTetap)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Durasi:', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        DropdownButton<int>(
                          value: _targetHours,
                          items: [
                            for (var h = 0; h <= 12; h++)
                              DropdownMenuItem(value: h, child: Text('$h jam')),
                          ],
                          onChanged: (v) => setState(() => _targetHours = v ?? 1),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<int>(
                          value: _targetMinutes,
                          items: [
                            for (var m = 0; m < 60; m += 15)
                              DropdownMenuItem(value: m, child: Text('$m mnt')),
                          ],
                          onChanged: (v) => setState(() => _targetMinutes = v ?? 0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Selesai ± ${formatClock(DateTime.now().add(Duration(hours: _targetHours, minutes: _targetMinutes)))}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.billiardGreenDark),
                    ),
                  ],
                ),
              ),
            ),
          if (_packages.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('Paket Main', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            for (final p in _packages) ...[
              _ModeCard(
                selected: _selectedPackage?.id == p.id,
                icon: p.tipe == PackageType.durasiFlat
                    ? Icons.card_giftcard_rounded
                    : Icons.local_offer_outlined,
                title:
                    '${p.namaPaket} — ${formatRupiah(p.harga)}${p.tipe == PackageType.tarifKhusus ? ' / jam' : ''}',
                subtitle:
                    '${p.tipe.label}${p.tipe == PackageType.durasiFlat && p.durasiMenit != null ? ' • ${p.durasiMenit! ~/ 60} jam ${p.durasiMenit! % 60} mnt' : ''} • ${p.hariLabel} • ${p.jamLabel}',
                onTap: () => setState(() {
                  _mode = p.tipe == PackageType.durasiFlat
                      ? _StartMode.paketFlat
                      : _StartMode.paketTarifKhusus;
                  _selectedPackage = p;
                }),
              ),
              const SizedBox(height: 10),
            ],
          ],
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppTheme.tableUsed, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.billiardGreen.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.billiardGreen : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.billiardGreenDark : Colors.grey.shade500, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.billiardGreen, size: 20),
          ],
        ),
      ),
    );
  }
}