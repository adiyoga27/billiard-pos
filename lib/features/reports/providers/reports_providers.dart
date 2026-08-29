import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pos/domain/product_models.dart';
import '../../tables/domain/table_models.dart';
import '../data/reports_repository.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) => ReportsRepository());

/// Parameter filter laporan: rentang tanggal + kasir.
class ReportFilter {
  final DateTime from;
  final DateTime to;
  final String? kasirId;

  const ReportFilter({required this.from, required this.to, this.kasirId});

  ReportFilter copyWith({DateTime? from, DateTime? to, String? kasirId}) => ReportFilter(
        from: from ?? this.from,
        to: to ?? this.to,
        kasirId: kasirId ?? this.kasirId,
      );
}

/// Data agregat laporan untuk sebuah filter.
class ReportData {
  final List<Transaction> transactions;
  final List<TableSession> sessions;
  final Map<DateTime, int> revenuePerDay;
  final List<TopProduct> topProducts;
  final Map<String, int> revenuePerTable;
  final int totalRevenue;
  final int counterRevenue;
  final int tableRevenue;

  const ReportData({
    required this.transactions,
    required this.sessions,
    required this.revenuePerDay,
    required this.topProducts,
    required this.revenuePerTable,
    required this.totalRevenue,
    required this.counterRevenue,
    required this.tableRevenue,
  });
}

final reportDataProvider = FutureProvider.autoDispose.family<ReportData, ReportFilter>((ref, filter) async {
  final repo = ref.watch(reportsRepositoryProvider);
  final transactions = await repo.transactionsInRange(
    from: filter.from,
    to: filter.to,
    kasirId: filter.kasirId,
  );
  final sessions = await repo.sessionsFinishedInRange(from: filter.from, to: filter.to);
  return ReportData(
    transactions: transactions,
    sessions: sessions,
    revenuePerDay: repo.revenuePerDay(transactions),
    topProducts: repo.topProducts(transactions),
    revenuePerTable: repo.revenuePerTable(sessions),
    totalRevenue: transactions.fold(0, (acc, t) => acc + t.total),
    counterRevenue: repo.counterRevenue(transactions),
    tableRevenue: repo.tableRevenue(transactions),
  );
});