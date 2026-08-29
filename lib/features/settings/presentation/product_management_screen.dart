import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/responsive_scaffold.dart';
import '../../pos/domain/product_models.dart';
import '../../pos/providers/pos_providers.dart';

/// Manajemen produk untuk POS.
class ProductManagementScreen extends ConsumerWidget {
  const ProductManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsStreamProvider);
    final categories = ref.watch(categoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produk & Kategori'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/settings/categories'),
            icon: const Icon(Icons.category_outlined),
            label: const Text('Kategori'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/settings/product-form'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Produk'),
      ),
      body: products.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (list) {
          final cats = categories.valueOrNull ?? const <Category>[];
          return CenteredContent(
            maxWidth: 860,
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.fastfood_rounded,
                    message: 'Belum ada produk',
                    hint: 'Tambahkan produk makanan/minuman untuk dijual di kasir.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final p = list[i];
                      final catName = cats.where((c) => c.id == p.kategoriId).firstOrNull?.nama ?? '-';
                      final lowStock = p.stok > 0 && p.stok <= 10;
                      return Card(
                        child: ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.billiardGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              p.outOfStock ? Icons.remove_shopping_cart_rounded : Icons.fastfood_rounded,
                              color: p.outOfStock ? Colors.grey : AppTheme.billiardGreenDark,
                            ),
                          ),
                          title: Text(p.nama, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Row(
                            children: [
                              Text(
                                '$catName • ${formatRupiah(p.harga)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                p.outOfStock
                                    ? ' • HABIS'
                                    : (lowStock ? ' • Sisa ${p.stok}' : ' • Stok ${p.stok}'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: p.outOfStock
                                      ? AppTheme.tableUsed
                                      : (lowStock ? AppTheme.tableReserved : Colors.grey.shade500),
                                ),
                              ),
                            ],
                          ),
                          onTap: () => context.push('/settings/product-form', extra: p),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') context.push('/settings/product-form', extra: p);
                              if (v == 'delete') _delete(context, ref, p);
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
          );
        },
      ),
    );
  }

  void _delete(BuildContext context, WidgetRef ref, Product p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Hapus ${p.nama}?'),
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
      await ref.read(posRepositoryProvider).deleteProduct(p.id);
    }
  }
}