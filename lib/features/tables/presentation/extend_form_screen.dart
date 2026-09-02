import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/form_page.dart';
import '../providers/tables_providers.dart';
import '../domain/table_models.dart';

/// Halaman perpanjang waktu sesi durasi tetap (bukan modal).
class ExtendFormScreen extends ConsumerStatefulWidget {
  final TableSession session;

  const ExtendFormScreen({super.key, required this.session});

  @override
  ConsumerState<ExtendFormScreen> createState() => _ExtendFormScreenState();
}

class _ExtendFormScreenState extends ConsumerState<ExtendFormScreen> {
  final _menitCtrl = TextEditingController(text: '30');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _menitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final minutes = int.tryParse(_menitCtrl.text) ?? 0;
    if (minutes <= 0) {
      setState(() => _error = 'Masukkan menit tambahan (minimal 1).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(tablesRepositoryProvider).extendSession(
            sessionId: widget.session.id,
            additionalMinutes: minutes,
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
    final session = widget.session;
    return FormPage(
      title: 'Perpanjang Waktu',
      saving: _saving,
      onSave: _save,
      saveLabel: 'Perpanjang',
      hint: 'Sesi meja ${session.tableName ?? ''} berakhir ${formatClock(session.waktuSelesaiTarget ?? session.waktuMulai)}. Durasi diperpanjang dari target saat ini.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _menitCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Menit tambahan',
              suffixText: 'menit',
              prefixIcon: Icon(Icons.add_alarm_rounded),
            ),
          ),
          if (session.riwayatPerpanjangan.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Sudah diperpanjang: ${session.riwayatPerpanjangan.join(' + ')} menit (total ${session.extendedMinutes} mnt).',
                style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
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