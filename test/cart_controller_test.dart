import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yesbilliard/core/domain/billing_calculator.dart';
import 'package:yesbilliard/features/pos/domain/product_models.dart';
import 'package:yesbilliard/features/pos/providers/pos_providers.dart';

void main() {
  const nasi = Product(id: 'p1', nama: 'Nasi Goreng', kategoriId: 'c1', harga: 25000, stok: 50);
  const esTeh = Product(id: 'p2', nama: 'Es Teh', kategoriId: 'c2', harga: 8000, stok: 80);

  group('CartController (POS walk-in)', () {
    test('tambah produk 2x → qty bertambah, bukan item dobel', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(cartControllerProvider.notifier);

      notifier.addProduct(nasi);
      notifier.addProduct(nasi);
      notifier.addProduct(esTeh);

      final state = container.read(cartControllerProvider);
      expect(state.itemList.length, 2);
      expect(state.itemCount, 3);
      expect(state.subtotal, 2 * 25000 + 8000);
    });

    test('setQty ke 0 menghapus item; clear mengosongkan; diskon tetap saat tambah', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(cartControllerProvider.notifier);

      notifier.addProduct(nasi);
      notifier.addProduct(nasi);
      notifier.setDiscount(const Discount(type: DiscountType.percent, value: 10));

      notifier.setQty('p1', 1);
      var state = container.read(cartControllerProvider);
      expect(state.itemCount, 1);
      expect(state.discount?.value, 10);

      notifier.setQty('p1', 0);
      state = container.read(cartControllerProvider);
      expect(state.isEmpty, isTrue);
      expect(state.discount, isNotNull);

      notifier.clear();
      state = container.read(cartControllerProvider);
      expect(state.isEmpty, isTrue);
      expect(state.discount, isNull);
    });
  });

  group('TableCartController (pesanan per meja)', () {
    test('cart tiap meja terpisah — meja 2 & 4 tidak campur', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(tableCartControllerProvider.notifier);

      notifier.addProduct('t2', nasi);
      notifier.addProduct('t2', nasi);
      notifier.addProduct('t4', esTeh);

      expect(notifier.itemCountOf('t2'), 2);
      expect(notifier.itemCountOf('t4'), 1);
      expect(notifier.subtotalOf('t2'), 50000);
      expect(notifier.subtotalOf('t4'), 8000);
      expect(notifier.cartOf('t9'), isEmpty);

      notifier.clearTable('t2');
      expect(notifier.itemCountOf('t2'), 0);
      expect(notifier.itemCountOf('t4'), 1);
    });

    test('tambah produk sama 2x → qty bertambah di cart meja', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(tableCartControllerProvider.notifier);

      notifier.addProduct('t1', nasi);
      notifier.addProduct('t1', nasi);
      final items = notifier.cartOf('t1');
      expect(items.length, 1);
      expect(items.single.qty, 2);
    });
  });
}
