import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/form_page.dart';
import '../../../core/domain/billing_calculator.dart';
import '../../tables/providers/tables_providers.dart';
import '../domain/settings_models.dart';

/// Halaman edit profil toko & tarif global (bukan modal — responsive penuh).
class GeneralSettingsFormScreen extends ConsumerStatefulWidget {
  final AppSettings settings;

  const GeneralSettingsFormScreen({super.key, required this.settings});

  @override
  ConsumerState<GeneralSettingsFormScreen> createState() =>
      _GeneralSettingsFormScreenState();
}

class _GeneralSettingsFormScreenState extends ConsumerState<GeneralSettingsFormScreen> {
  late final TextEditingController _namaCtrl =
      TextEditingController(text: widget.settings.namaToko);
  late final TextEditingController _alamatCtrl =
      TextEditingController(text: widget.settings.alamat);
  late final TextEditingController _telpCtrl =
      TextEditingController(text: widget.settings.noTelp);
  late final TextEditingController _ambangCtrl =
      TextEditingController(text: '${widget.settings.ambangPeringatanMenit}');
  late final TextEditingController _pajakCtrl =
      TextEditingController(text: widget.settings.pajakPersen.toStringAsFixed(0));
  late final TextEditingController _scCtrl =
      TextEditingController(text: widget.settings.serviceChargePersen.toStringAsFixed(0));
  late RoundingMode _pembulatan = widget.settings.pembulatan;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _namaCtrl.dispose();
    _alamatCtrl.dispose();
    _telpCtrl.dispose();
    _ambangCtrl.dispose();
    _pajakCtrl.dispose();
    _scCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = AppSettings(
        namaToko: _namaCtrl.text.trim().isEmpty ? widget.settings.namaToko : _namaCtrl.text.trim(),
        alamat: _alamatCtrl.text.trim(),
        noTelp: _telpCtrl.text.trim(),
        pembulatan: _pembulatan,
        ambangPeringatanMenit: int.tryParse(_ambangCtrl.text) ?? widget.settings.ambangPeringatanMenit,
        pajakPersen: double.tryParse(_pajakCtrl.text) ?? widget.settings.pajakPersen,
        serviceChargePersen: double.tryParse(_scCtrl.text) ?? widget.settings.serviceChargePersen,
      );
      await ref.read(settingsRepositoryProvider).updateSettings(updated);
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
      title: 'Profil Toko & Tarif',
      saving: _saving,
      onSave: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _namaCtrl,
            decoration: const InputDecoration(
              labelText: 'Nama toko',
              prefixIcon: Icon(Icons.storefront_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _alamatCtrl,
            decoration: const InputDecoration(
              labelText: 'Alamat',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _telpCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'No. telepon',
              prefixIcon: Icon(Icons.phone_outlined),
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
          const SizedBox(height: 14),
          TextField(
            controller: _ambangCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Ambang peringatan sesi',
              hintText: 'Menit sebelum waktu habis (default 10)',
              suffixText: 'menit',
              prefixIcon: Icon(Icons.notifications_active_outlined),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pajakCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Pajak (%)',
                    prefixIcon: Icon(Icons.percent_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _scCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Service charge (%)',
                    prefixIcon: Icon(Icons.support_agent_rounded),
                  ),
                ),
              ),
            ],
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