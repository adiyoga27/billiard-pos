import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/form_page.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/tables_providers.dart';
import '../domain/table_models.dart';

/// Halaman tambah biaya tambahan dinamis sesi (sewa stik premium, ganti bola,
/// kerusakan, dsb) — bukan modal.
class ChargeFormScreen extends ConsumerStatefulWidget {
  final TableSession session;

  const ChargeFormScreen({super.key, required this.session});

  @override
  ConsumerState<ChargeFormScreen> createState() => _ChargeFormScreenState();
}

class _ChargeFormScreenState extends ConsumerState<ChargeFormScreen> {
  final _namaCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _hargaCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _namaCtrl.dispose();
    _qtyCtrl.dispose();
    _hargaCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nama = _namaCtrl.text.trim();
    final jumlah = int.tryParse(_qtyCtrl.text) ?? 0;
    final harga = int.tryParse(_hargaCtrl.text) ?? 0;
    if (nama.isEmpty || jumlah <= 0 || harga <= 0) {
      setState(() => _error = 'Lengkapi nama biaya, jumlah, dan harga satuan.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = ref.read(currentUserProvider);
      await ref.read(tablesRepositoryProvider).addExtraCharge(
            sessionId: widget.session.id,
            nama: nama,
            jumlah: jumlah,
            hargaSatuan: harga,
            kasirId: user?.uid ?? '',
          );
      if (mounted) context.pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Gagal: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Biaya Tambahan',
      saving: _saving,
      onSave: _save,
      saveLabel: 'Tambahkan',
      hint: 'Biaya di luar katalog produk, misal sewa stik premium, ganti bola, biaya kerusakan.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _namaCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nama biaya',
              hintText: 'mis. Sewa stik premium',
              prefixIcon: Icon(Icons.add_circle_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Jumlah',
                    prefixIcon: Icon(Icons.numbers_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _hargaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Harga satuan (Rp)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
              ),
            ],
          ),
          if (widget.session.biayaTambahan.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Biaya tambahan aktif:',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700)),
                  for (final c in widget.session.biayaTambahan)
                    Text(
                      '• ${c.nama} (${c.jumlah}x) — Rp ${c.subtotal}',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
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