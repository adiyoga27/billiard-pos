import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/pos_providers.dart';
import '../../../shared/widgets/product_grid.dart';

/// Halaman pemilihan produk untuk PESANAN MEJA (bukan modal).
/// Item yang dipilih masuk ke cart meja tersebut (terpisah per meja).
class OrderPickerScreen extends ConsumerWidget {
  final String tableId;

  const OrderPickerScreen({super.key, required this.tableId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Pesanan Meja')),
      body: ProductGridProvider(
        onAdd: (product) {
          ref.read(tableCartControllerProvider.notifier).addProduct(tableId, product);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${product.nama} ditambahkan ke pesanan meja'),
              duration: const Duration(milliseconds: 900),
            ),
          );
        },
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      ),
    );
  }
}