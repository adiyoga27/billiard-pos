import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/responsive_scaffold.dart';
import '../../pos/domain/product_models.dart';
import '../../pos/providers/pos_providers.dart';

/// Manajemen kategori produk.
class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kategori Produk')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/settings/category-form'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Kategori'),
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (list) => CenteredContent(
          maxWidth: 860,
          child: list.isEmpty
              ? const EmptyState(
                  icon: Icons.category_outlined,
                  message: 'Belum ada kategori',
                  hint: 'Kelompokkan produk (makanan, minuman, snack).',
                )
              : ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final c = list[i];
            return Card(
              child: ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.billiardGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.category_outlined, color: AppTheme.billiardGreenDark),
                ),
                title: Text(c.nama, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') context.push('/settings/category-form', extra: c);
                    if (v == 'delete') _delete(context, ref, c);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Hapus')),
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

  void _delete(BuildContext context, WidgetRef ref, Category c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Hapus kategori ${c.nama}?'),
        content: const Text('Produk dalam kategori ini juga akan dihapus.'),
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
      await ref.read(posRepositoryProvider).deleteCategory(c.id);
    }
  }
}