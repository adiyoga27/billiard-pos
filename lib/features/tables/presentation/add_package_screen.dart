import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/form_page.dart';

import '../domain/package_models.dart';
import '../domain/table_models.dart';
import '../providers/tables_providers.dart';

/// Halaman tambah PAKET di tengah sesi (bukan modal):
/// pilih paket durasi flat → durasi bertambah + biaya tercatat di tagihan.
/// Contoh: beli "Paket 3 Jam", lalu di menit ke-120 beli lagi "Paket 3 Jam".
class AddPackageScreen extends ConsumerStatefulWidget {
  final TableSession session;

  const AddPackageScreen({super.key, required this.session});

  @override
  ConsumerState<AddPackageScreen> createState() => _AddPackageScreenState();
}

class _AddPackageScreenState extends ConsumerState<AddPackageScreen> {
  final Set<String> _adding = {};

  Future<void> _add(PlayPackage p) async {
    setState(() => _adding.add(p.id));
    try {
      await ref.read(tablesRepositoryProvider).addPackageToSession(
            sessionId: widget.session.id,
            paket: p,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${p.namaPaket} ditambahkan — durasi +${p.durasiMenit! ~/ 60}j ${p.durasiMenit! % 60}m, biaya ${formatRupiah(p.harga)}',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _adding.remove(p.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final packages = ref.watch(applicablePackagesProvider(widget.session.tableId)).valueOrNull ??
        const <PlayPackage>[];
    final flatPackages = packages.where((p) => p.tipe == PackageType.durasiFlat).toList();

    return FormPage(
      title: 'Tambah Paket ke Sesi',
      hint: 'Durasi bertambah sesuai paket & biaya masuk ke breakdown tagihan sesi.',
      child: flatPackages.isEmpty
          ? Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Tidak ada paket durasi yang tersedia untuk meja ini saat ini. Cek syarat berlaku paket (hari/jam/meja).',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final p in flatPackages)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.billiardGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.card_giftcard_rounded, color: AppTheme.billiardGreenDark),
                        ),
                        title: Text(p.namaPaket, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          '+${p.durasiMenit! ~/ 60}j ${p.durasiMenit! % 60}m • ${formatRupiah(p.harga)} • ${p.hariLabel} • ${p.jamLabel}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: _adding.contains(p.id)
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : FilledButton(
                                onPressed: () => _add(p),
                                child: const Text('Tambah'),
                              ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}