import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../features/pos/domain/product_models.dart';
import '../../features/pos/providers/pos_providers.dart';

/// Grid produk + pencarian + filter kategori — dipakai bersama oleh
/// POS walk-in dan picker pesanan meja.
class ProductGrid extends StatefulWidget {
  final List<Product> products;
  final List<Category> categories;
  final void Function(Product) onAdd;
  final EdgeInsets padding;

  const ProductGrid({
    super.key,
    required this.products,
    required this.categories,
    required this.onAdd,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends State<ProductGrid> {
  String _search = '';
  String _selectedCategory = 'semua';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.products.where((p) {
      final matchCat = _selectedCategory == 'semua' || p.kategoriId == _selectedCategory;
      final matchSearch = _search.isEmpty || p.nama.toLowerCase().contains(_search.toLowerCase());
      return matchCat && matchSearch;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final searchField = TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Cari produk...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              );
              final filterButton = PopupMenuButton<String>(
                initialValue: _selectedCategory,
                onSelected: (v) => setState(() => _selectedCategory = v),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'semua', child: Text('Semua kategori')),
                  for (final c in widget.categories)
                    PopupMenuItem(value: c.id, child: Text(c.nama)),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.categories.where((c) => c.id == _selectedCategory).firstOrNull?.nama ??
                            'Semua',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down_rounded),
                    ],
                  ),
                ),
              );

              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    searchField,
                    const SizedBox(height: 8),
                    filterButton,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 10),
                  filterButton,
                ],
              );
            },
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('Produk tidak ditemukan', style: TextStyle(color: Colors.grey.shade500)),
                )
              : GridView.builder(
                  padding: widget.padding,
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.92,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    final cat = widget.categories.where((c) => c.id == p.kategoriId).firstOrNull;
                    return _ProductCard(
                      product: p,
                      categoryName: cat?.nama,
                      onAdd: widget.onAdd,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// ProductGrid yang sudah terhubung ke stream produk/kategori dari Riverpod.
class ProductGridProvider extends ConsumerWidget {
  final void Function(Product) onAdd;
  final EdgeInsets padding;

  const ProductGridProvider({super.key, required this.onAdd, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsStreamProvider);
    final categories = ref.watch(categoriesStreamProvider);
    return products.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Gagal memuat produk: $e')),
      data: (productList) => ProductGrid(
        products: productList,
        categories: categories.valueOrNull ?? const [],
        onAdd: onAdd,
        padding: padding,
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final String? categoryName;
  final void Function(Product) onAdd;

  const _ProductCard({required this.product, required this.categoryName, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final disabled = product.outOfStock;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: disabled ? null : () => onAdd(product),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 64,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.billiardGreen.withValues(alpha: 0.14),
                        AppTheme.billiardGreen.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    product.stok > 20 ? Icons.local_drink_rounded : Icons.fastfood_rounded,
                    color: AppTheme.billiardGreenDark,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  product.nama,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.2),
                ),
                const Spacer(),
                Text(
                  formatRupiah(product.harga),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.billiardGreenDark),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        disabled
                            ? 'Habis'
                            : (product.stok <= 10 ? 'Sisa ${product.stok}' : (categoryName ?? 'Produk')),
                        style: TextStyle(
                          fontSize: 11,
                          color: product.stok <= 10 && !disabled ? AppTheme.tableReserved : Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton.filled(
                      onPressed: disabled ? null : () => onAdd(product),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.billiardGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(6),
                        minimumSize: const Size(30, 30),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}