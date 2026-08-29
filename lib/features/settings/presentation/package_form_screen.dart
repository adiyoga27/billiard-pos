import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/form_page.dart';
import '../../tables/providers/tables_providers.dart';
import '../../tables/domain/package_models.dart';

/// Halaman tambah/edit paket main billiard (bukan modal — responsive penuh).
class PackageFormScreen extends ConsumerStatefulWidget {
  final PlayPackage? paket;

  const PackageFormScreen({super.key, this.paket});

  @override
  ConsumerState<PackageFormScreen> createState() => _PackageFormScreenState();
}

class _PackageFormScreenState extends ConsumerState<PackageFormScreen> {
  late final TextEditingController _namaCtrl =
      TextEditingController(text: widget.paket?.namaPaket ?? '');
  late final TextEditingController _hargaCtrl =
      TextEditingController(text: widget.paket != null ? '${widget.paket!.harga}' : '');
  late final TextEditingController _durasiCtrl = TextEditingController(
    text: widget.paket?.durasiMenit != null ? '${widget.paket!.durasiMenit}' : '120',
  );
  late PackageType _tipe = widget.paket?.tipe ?? PackageType.durasiFlat;
  late final Set<int> _hariAktif = {...?widget.paket?.hariAktif};
  late int? _jamMulai = widget.paket?.jamMulaiBerlaku;
  late int? _jamSelesai = widget.paket?.jamSelesaiBerlaku;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _namaCtrl.dispose();
    _hargaCtrl.dispose();
    _durasiCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nama = _namaCtrl.text.trim();
    final harga = int.tryParse(_hargaCtrl.text) ?? 0;
    if (nama.isEmpty || harga <= 0) {
      setState(() => _error = 'Nama paket dan harga wajib diisi.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(tablesRepositoryProvider).savePackage(PlayPackage(
            id: widget.paket?.id ?? '',
            namaPaket: nama,
            tipe: _tipe,
            durasiMenit:
                _tipe == PackageType.durasiFlat ? (int.tryParse(_durasiCtrl.text) ?? 120) : null,
            harga: harga,
            hariAktif: _hariAktif.toList()..sort(),
            jamMulaiBerlaku: _jamMulai,
            jamSelesaiBerlaku: _jamSelesai,
            berlakuUntukMeja: const [],
            isActive: widget.paket?.isActive ?? true,
          ));
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
      title: widget.paket == null ? 'Tambah Paket' : 'Edit Paket',
      saving: _saving,
      onSave: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _namaCtrl,
            decoration: const InputDecoration(
              labelText: 'Nama paket',
              prefixIcon: Icon(Icons.card_giftcard_rounded),
            ),
          ),
          const SizedBox(height: 14),
          SegmentedButton<PackageType>(
            segments: const [
              ButtonSegment(value: PackageType.durasiFlat, label: Text('Durasi flat')),
              ButtonSegment(value: PackageType.tarifKhusus, label: Text('Tarif / jam')),
            ],
            selected: {_tipe},
            onSelectionChanged: (s) => setState(() => _tipe = s.first),
          ),
          const SizedBox(height: 14),
          if (_tipe == PackageType.durasiFlat)
            TextField(
              controller: _durasiCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Durasi paket',
                suffixText: 'menit',
                prefixIcon: Icon(Icons.timer_outlined),
              ),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _hargaCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _tipe == PackageType.durasiFlat ? 'Harga paket (Rp)' : 'Tarif per jam (Rp)',
              prefixIcon: const Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Hari aktif (kosong = semua hari)',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(_hariNames[d]!),
                  selected: _hariAktif.contains(d),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _hariAktif.add(d);
                    } else {
                      _hariAktif.remove(d);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Jam berlaku (kosong = semua jam)',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _jamMulai,
                  decoration: const InputDecoration(labelText: 'Mulai jam'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Semua jam')),
                    for (var h = 0; h < 24; h++)
                      DropdownMenuItem(value: h, child: Text('${h.toString().padLeft(2, '0')}:00')),
                  ],
                  onChanged: (v) => setState(() => _jamMulai = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _jamSelesai,
                  decoration: const InputDecoration(labelText: 'Selesai jam'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Semua jam')),
                    for (var h = 0; h < 24; h++)
                      DropdownMenuItem(value: h, child: Text('${h.toString().padLeft(2, '0')}:00')),
                  ],
                  onChanged: (v) => setState(() => _jamSelesai = v),
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

  static const _hariNames = {
    1: 'Senin',
    2: 'Selasa',
    3: 'Rabu',
    4: 'Kamis',
    5: 'Jumat',
    6: 'Sabtu',
    7: 'Minggu',
  };
}