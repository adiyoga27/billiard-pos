import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

import '../../pos/domain/product_models.dart';
import '../../tables/domain/table_models.dart';

class ReportsRepository {
  final FirebaseFirestore _db;

  ReportsRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  /// Ambil transaksi dalam rentang waktu (dari awal hari [from] sampai akhir hari [to]).
  ///
  /// Hanya pakai filter range `created_at` (single-field, tidak butuh
  /// composite index); filter kasir dilakukan di sisi klien supaya laporan
  /// selalu bisa dibuka tanpa deploy index manual.
  Future<List<Transaction>> transactionsInRange({
    required DateTime from,
    required DateTime to,
    String? kasirId,
  }) async {
    final snap = await _db
        .collection('transactions')
        .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('created_at', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .orderBy('created_at', descending: true)
        .get();
    final list = snap.docs.map((d) => Transaction.fromFirestore(d.id, d.data())).toList();
    if (kasirId != null) {
      list.removeWhere((t) => t.kasirId != kasirId);
    }
    return list;
  }

  /// Sesi meja yang selesai dalam rentang (untuk pendapatan per meja).
  /// Filter rentang dilakukan di sisi klien supaya query tidak butuh
  /// composite index (status + waktu_selesai) di Firestore.
  Future<List<TableSession>> sessionsFinishedInRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final snap = await _db
        .collection('table_sessions')
        .where('status', isEqualTo: 'selesai')
        .get();
    return snap.docs
        .map((d) => TableSession.fromFirestore(d.id, d.data()))
        .where((s) =>
            s.waktuSelesai != null &&
            !s.waktuSelesai!.isBefore(from) &&
            !s.waktuSelesai!.isAfter(to))
        .toList();
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