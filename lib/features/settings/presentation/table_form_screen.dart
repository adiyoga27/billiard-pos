import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/form_page.dart';
import '../../tables/providers/tables_providers.dart';
import '../../../core/domain/billing_calculator.dart';
import '../../tables/domain/table_models.dart';

/// Halaman tambah/edit meja (bukan modal — responsive penuh).
class TableFormScreen extends ConsumerStatefulWidget {
  final BillTable? table;

  const TableFormScreen({super.key, this.table});

  @override
  ConsumerState<TableFormScreen> createState() => _TableFormScreenState();
}

class _TableFormScreenState extends ConsumerState<TableFormScreen> {
  late final TextEditingController _namaCtrl =
      TextEditingController(text: widget.table?.namaMeja ?? '');
  late final TextEditingController _tarifCtrl =
      TextEditingController(text: widget.table != null ? '${widget.table!.tarifPerJam}' : '');
  late RoundingMode _pembulatan = widget.table?.metodePembulatan ?? RoundingMode.per15Minutes;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _namaCtrl.dispose();
    _tarifCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nama = _namaCtrl.text.trim();
    final tarif = int.tryParse(_tarifCtrl.text) ?? 0;
    if (nama.isEmpty || tarif <= 0) {
      setState(() => _error = 'Nama meja dan tarif per jam wajib diisi.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(tablesRepositoryProvider).saveTable(
            id: widget.table?.id,
            namaMeja: nama,
            tarifPerJam: tarif,
            pembulatan: _pembulatan,
          );
      if (mounted) context.pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Gagal menyimpan: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: widget.table == null ? 'Tambah Meja' : 'Edit ${widget.table!.namaMeja}',
      saving: _saving,
      onSave: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _namaCtrl,
            decoration: const InputDecoration(
              labelText: 'Nama / nomor meja',
              prefixIcon: Icon(AppTheme.billiardIcon),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _tarifCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Tarif per jam (Rp)',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<RoundingMode>(
            initialValue: _pembulatan,
            decoration: const InputDecoration(
              labelText: 'Pembulatan waktu sewa',
              prefixIcon: Icon(Icons.timer_outlined),
            ),
            items: [
              for (final m in RoundingMode.values)
                DropdownMenuItem(value: m, child: Text(m.label)),
            ],
            onChanged: (v) => setState(() => _pembulatan = v ?? _pembulatan),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: AppTheme.tableUsed, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}