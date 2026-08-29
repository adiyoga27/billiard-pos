import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/billing_calculator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/form_page.dart';
import '../providers/tables_providers.dart';
import '../domain/table_models.dart';

/// Halaman diskon sesi meja (persen/nominal, dengan alasan opsional).
class DiscountFormScreen extends ConsumerStatefulWidget {
  final TableSession session;

  const DiscountFormScreen({super.key, required this.session});

  @override
  ConsumerState<DiscountFormScreen> createState() => _DiscountFormScreenState();
}

class _DiscountFormScreenState extends ConsumerState<DiscountFormScreen> {
  late bool _usePercent = widget.session.diskon?.type == DiscountType.percent;
  late final TextEditingController _nilaiCtrl =
      TextEditingController(text: widget.session.diskon != null ? '${widget.session.diskon!.value}' : '');
  late final TextEditingController _alasanCtrl =
      TextEditingController(text: widget.session.diskon?.reason ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nilaiCtrl.dispose();
    _alasanCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nilai = int.tryParse(_nilaiCtrl.text) ?? 0;
    if (nilai <= 0) {
      setState(() => _error = 'Nilai diskon harus lebih dari 0.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(tablesRepositoryProvider).setSessionDiscount(
            sessionId: widget.session.id,
            type: _usePercent ? DiscountType.percent : DiscountType.nominal,
            value: nilai,
            reason: _alasanCtrl.text.trim().isEmpty ? null : _alasanCtrl.text.trim(),
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
      title: widget.session.diskon != null ? 'Ubah Diskon Sesi' : 'Diskon Sesi',
      saving: _saving,
      onSave: _save,
      hint: 'Diskon berlaku ke biaya sesi meja (sewa + biaya tambahan + paket tambahan).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Persen (%)')),
              ButtonSegment(value: false, label: Text('Nominal (Rp)')),
            ],
            selected: {_usePercent},
            onSelectionChanged: (s) => setState(() => _usePercent = s.first),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nilaiCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: _usePercent ? 'Nilai diskon (%)' : 'Nilai diskon (Rp)',
              prefixIcon: const Icon(Icons.percent_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _alasanCtrl,
            decoration: const InputDecoration(
              labelText: 'Alasan (opsional)',
              hintText: 'mis. promo member',
              prefixIcon: Icon(Icons.sticky_note_2_outlined),
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