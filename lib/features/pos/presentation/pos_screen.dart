import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/billing_calculator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/product_grid.dart';
import '../../../shared/widgets/responsive_scaffold.dart';
import '../providers/pos_providers.dart';
import 'package:go_router/go_router.dart';

/// Layar kasir POS — khusus transaksi WALK-IN / counter sale (tanpa meja).
/// Pesanan yang menyertakan meja dikelola di halaman detail meja,
/// supaya cart tiap meja tidak tercampur.
class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 1000;

    return ResponsiveScaffold(
      currentLocation: '/pos',
      child: Column(
        children: [
          PageHeader(
            title: 'Kasir Walk-in',
            subtitle: 'Penjualan langsung tanpa meja (makanan & minuman)',
            actions: [
              if (!wide)
                Badge(
                  label: Text('${cart.itemCount}'),
                  child: FilledButton.icon(
                    onPressed: () => _openCart(context),
                    icon: const Icon(Icons.shopping_cart_outlined),
                    label: const Text('Keranjang'),
                  ),
                ),
            ],
          ),
          Expanded(
            child: wide
                ? Row(
                    children: [
                      Expanded(
                        child: ProductGridProvider(
                          onAdd: (p) =>
                              ref.read(cartControllerProvider.notifier).addProduct(p),
                          padding: const EdgeInsets.fromLTRB(20, 4, 12, 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: SizedBox(
                          width: 400,
                          child: _CartPanel(cart: cart),
                        ),
                      ),
                    ],
                  )
                : ProductGridProvider(
                    onAdd: (p) => ref.read(cartControllerProvider.notifier).addProduct(p),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  ),
          ),
          if (!wide)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${cart.itemCount} item',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        Text(
                          formatRupiah(cart.subtotal),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: cart.isEmpty ? null : () => _openCart(context),
                    icon: const Icon(Icons.payment_rounded),
                    label: const Text('Checkout'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _openCart(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final cart = ref.watch(cartControllerProvider);
          return SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.8,
            child: _CartPanel(cart: cart),
          );
        },
      ),
    );
  }
}

class _CartPanel extends ConsumerWidget {
  final CartState cart;

  const _CartPanel({required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(cartControllerProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_outlined, size: 22, color: AppTheme.billiardGreenDark),
                const SizedBox(width: 8),
                const Text('Keranjang', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const Spacer(),
                if (!cart.isEmpty)
                  TextButton(
                    onPressed: controller.clear,
                    child: const Text('Kosongkan'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_shopping_cart_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text('Keranjang kosong', style: TextStyle(color: Colors.grey.shade500)),
                        const SizedBox(height: 4),
                        Text(
                          'Tap produk untuk menambahkan',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: cart.itemList.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final item = cart.itemList[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.billiardGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.fastfood_rounded, size: 20, color: AppTheme.billiardGreenDark),
                        ),
                        title: Text(item.product.nama, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        subtitle: Text(
                          '${formatRupiah(item.product.harga)} x ${item.qty}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _QtyButton(
                              icon: Icons.remove_rounded,
                              onTap: () => controller.setQty(item.product.id, item.qty - 1),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text('${item.qty}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            _QtyButton(
                              icon: Icons.add_rounded,
                              onTap: () => controller.addProduct(item.product),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _SummaryRow(label: 'Subtotal', value: cart.subtotal),
                if (cart.discount != null)
                  _SummaryRow(
                    label: 'Diskon${cart.discount!.reason != null ? ' (${cart.discount!.reason})' : ''}',
                    value: -discountAmount(cart.subtotal, cart.discount),
                    color: AppTheme.tableFree,
                  ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(
                      formatRupiah(cart.subtotal - discountAmount(cart.subtotal, cart.discount)),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.billiardGreenDark),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: cart.isEmpty
                        ? null
                        : () => context.push('/checkout', extra: {
                              'items': cart.itemList,
                              'title': 'Checkout Walk-in',
                            }),
                    icon: const Icon(Icons.payment_rounded),
                    label: const Text('Checkout & Bayar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final int value;
  final Color? color;

  const _SummaryRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13.5, color: color ?? Colors.grey.shade700)),
          Text(
            '${value < 0 ? '-' : ''}${formatRupiah(value.abs())}',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: color),
          ),
        ],
      ),
    );
  }
}