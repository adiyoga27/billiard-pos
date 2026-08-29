import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/billing_calculator.dart';
import '../data/pos_repository.dart';
import '../domain/product_models.dart';

final posRepositoryProvider = Provider<PosRepository>((ref) => PosRepository());

final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(posRepositoryProvider).categoriesStream();
});

final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(posRepositoryProvider).productsStream();
});

final transactionsStreamProvider = StreamProvider<List<Transaction>>((ref) {
  return ref.watch(posRepositoryProvider).transactionsStream();
});

/// Item keranjang (dipakai POS walk-in DAN cart per meja).
class CartItem {
  final Product product;
  int qty;

  CartItem(this.product, this.qty);

  int get subtotal => product.harga * qty;
}

/// State keranjang transaksi POS walk-in.
class CartState {
  final Map<String, CartItem> items;
  final Discount? discount;

  const CartState({this.items = const {}, this.discount});

  List<CartItem> get itemList => items.values.toList();

  int get itemCount => items.values.fold(0, (acc, i) => acc + i.qty);

  int get subtotal => items.values.fold(0, (acc, i) => acc + i.subtotal);

  bool get isEmpty => items.isEmpty;
}

class CartController extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  void addProduct(Product product, {int qty = 1}) {
    final items = Map<String, CartItem>.from(state.items);
    final existing = items[product.id];
    if (existing != null) {
      existing.qty += qty;
    } else {
      items[product.id] = CartItem(product, qty);
    }
    state = CartState(items: items, discount: state.discount);
  }

  void setQty(String productId, int qty) {
    final items = Map<String, CartItem>.from(state.items);
    if (qty <= 0) {
      items.remove(productId);
    } else {
      items[productId]?.qty = qty;
    }
    state = CartState(items: items, discount: state.discount);
  }

  void removeProduct(String productId) => setQty(productId, 0);

  void clear() => state = const CartState();

  void setDiscount(Discount? discount) {
    state = CartState(items: state.items, discount: discount);
  }
}

final cartControllerProvider = NotifierProvider<CartController, CartState>(CartController.new);

/// Keranjang PESANAN PER MEJA — setiap meja punya cart sendiri, jadi pesanan
/// meja 2 dan meja 4 tidak saling tercampur.
class TableCartController extends Notifier<Map<String, List<CartItem>>> {
  @override
  Map<String, List<CartItem>> build() => const {};

  List<CartItem> cartOf(String tableId) => state[tableId] ?? const [];

  int itemCountOf(String tableId) => cartOf(tableId).fold(0, (acc, i) => acc + i.qty);

  int subtotalOf(String tableId) => cartOf(tableId).fold(0, (acc, i) => acc + i.subtotal);

  void addProduct(String tableId, Product product, {int qty = 1}) {
    final carts = Map<String, List<CartItem>>.from(state);
    final items = [...(carts[tableId] ?? const <CartItem>[])];
    final idx = items.indexWhere((i) => i.product.id == product.id);
    if (idx >= 0) {
      items[idx].qty += qty;
    } else {
      items.add(CartItem(product, qty));
    }
    carts[tableId] = items;
    state = carts;
  }

  void setQty(String tableId, String productId, int qty) {
    final carts = Map<String, List<CartItem>>.from(state);
    final items = [...(carts[tableId] ?? const <CartItem>[])];
    final idx = items.indexWhere((i) => i.product.id == productId);
    if (idx < 0) return;
    if (qty <= 0) {
      items.removeAt(idx);
    } else {
      items[idx].qty = qty;
    }
    carts[tableId] = items;
    state = carts;
  }

  void removeProduct(String tableId, String productId) => setQty(tableId, productId, 0);

  void clearTable(String tableId) {
    final carts = Map<String, List<CartItem>>.from(state);
    carts.remove(tableId);
    state = carts;
  }
}

final tableCartControllerProvider =
    NotifierProvider<TableCartController, Map<String, List<CartItem>>>(TableCartController.new);