import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/responsive_scaffold.dart';
import '../../tables/domain/package_models.dart';
import '../../tables/providers/tables_providers.dart';

/// Manajemen paket main billiard (admin).
class PackageManagementScreen extends ConsumerWidget {
  const PackageManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packages = ref.watch(packagesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Paket Main Billiard')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/settings/package-form'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Paket'),
      ),
      body: packages.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (list) => CenteredContent(
          maxWidth: 860,
          child: list.isEmpty
              ? const EmptyState(
                  icon: Icons.card_giftcard_rounded,
                  message: 'Belum ada paket main',
                  hint: 'Buat paket durasi flat atau tarif khusus.',
                )
              : ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final p = list[i];
            return Card(
              child: ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (p.isActive ? AppTheme.billiardGreen : Colors.grey).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    p.tipe == PackageType.durasiFlat
                        ? Icons.card_giftcard_rounded
                        : Icons.local_offer_outlined,
                    color: p.isActive ? AppTheme.billiardGreen : Colors.grey,
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(p.namaPaket, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    if (!p.isActive)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Nonaktif', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                subtitle: Text(
                  '${p.tipe.label} • ${formatRupiah(p.harga)}${p.tipe == PackageType.tarifKhusus ? '/jam' : ''}'
                  '${p.tipe == PackageType.durasiFlat && p.durasiMenit != null ? ' • ${p.durasiMenit! ~/ 60}j ${p.durasiMenit! % 60}m' : ''}\n'
                  '${p.hariLabel} • ${p.jamLabel}',
                  style: const TextStyle(fontSize: 12),
                ),
                isThreeLine: true,
                onTap: () => context.push('/settings/package-form', extra: p),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') context.push('/settings/package-form', extra: p);
                    if (v == 'toggle') _toggle(context, ref, p);
                    if (v == 'delete') _delete(context, ref, p);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(p.isActive ? 'Nonaktifkan' : 'Aktifkan'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, PlayPackage p) async {
    await ref.read(tablesRepositoryProvider).savePackage(p.copyWith2(isActive: !p.isActive));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, PlayPackage p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Hapus ${p.namaPaket}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.tableUsed),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(tablesRepositoryProvider).deletePackage(p.id);
    }
  }
}

extension _PkgX on PlayPackage {
  PlayPackage copyWith2({bool? isActive}) => PlayPackage(
        id: id,
        namaPaket: namaPaket,
        tipe: tipe,
        durasiMenit: durasiMenit,
        harga: harga,
        hariAktif: hariAktif,
        jamMulaiBerlaku: jamMulaiBerlaku,
        jamSelesaiBerlaku: jamSelesaiBerlaku,
        berlakuUntukMeja: berlakuUntukMeja,
        isActive: isActive ?? this.isActive,
      );
}