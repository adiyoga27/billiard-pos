import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

import '../../pos/domain/product_models.dart';
import '../../tables/domain/table_models.dart';

class ReportsRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Ambil transaksi dalam rentang waktu (dari awal hari [from] sampai akhir hari [to]).
  Future<List<Transaction>> transactionsInRange({
    required DateTime from,
    required DateTime to,
    String? kasirId,
  }) async {
    var query = _db
        .collection('transactions')
        .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('created_at', isLessThanOrEqualTo: Timestamp.fromDate(to));
    if (kasirId != null) {
      query = query.where('kasir_id', isEqualTo: kasirId);
    }
    final snap = await query.orderBy('created_at', descending: true).get();
    return snap.docs.map((d) => Transaction.fromFirestore(d.id, d.data())).toList();
  }

  /// Sesi meja yang selesai dalam rentang (untuk pendapatan per meja).
  Future<List<TableSession>> sessionsFinishedInRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final snap = await _db
        .collection('table_sessions')
        .where('status', isEqualTo: 'selesai')
        .where('waktu_selesai', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('waktu_selesai', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .get();
    return snap.docs.map((d) => TableSession.fromFirestore(d.id, d.data())).toList();
  }

  /// Agregasi penjualan per hari dalam rentang.
  Map<DateTime, int> revenuePerDay(List<Transaction> transactions) {
    final map = <DateTime, int>{};
    for (final t in transactions) {
      final day = DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
      map[day] = (map[day] ?? 0) + t.total;
    }
    return map;
  }

  /// Produk terlaris (qty) dalam rentang.
  List<TopProduct> topProducts(List<Transaction> transactions, {int limit = 10}) {
    final map = <String, TopProduct>{};
    for (final t in transactions) {
      for (final item in t.items) {
        final existing = map[item.productId];
        if (existing == null) {
          map[item.productId] = TopProduct(nama: item.nama, qty: item.qty, revenue: item.subtotal);
        } else {
          map[item.productId] = TopProduct(
            nama: existing.nama,
            qty: existing.qty + item.qty,
            revenue: existing.revenue + item.subtotal,
          );
        }
      }
    }
    final list = map.values.toList()..sort((a, b) => b.qty.compareTo(a.qty));
    return list.take(limit).toList();
  }

  /// Pendapatan per meja billiard (dari sesi yang selesai dalam rentang).
  Map<String, int> revenuePerTable(List<TableSession> sessions) {
    final map = <String, int>{};
    for (final s in sessions) {
      final name = s.tableName ?? 'Meja';
      map[name] = (map[name] ?? 0) + s.biaya;
    }
    return map;
  }

  /// Total transaksi counter (tanpa sesi meja) vs gabungan.
  int counterRevenue(List<Transaction> transactions) =>
      transactions.where((t) => !t.sessionFinalized).fold(0, (acc, t) => acc + t.total);

  int tableRevenue(List<Transaction> transactions) =>
      transactions.where((t) => t.sessionFinalized).fold(0, (acc, t) => acc + t.total);
}

class TopProduct {
  final String nama;
  final int qty;
  final int revenue;

  const TopProduct({required this.nama, required this.qty, required this.revenue});
}