import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/responsive_scaffold.dart';
import '../../auth/providers/auth_providers.dart';
import '../../pos/domain/product_models.dart';
import '../data/reports_repository.dart';
import '../providers/reports_providers.dart';

enum _RangePreset { today, week, month }

/// Laporan penjualan: grafik harian, ringkasan, produk terlaris, per meja.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _RangePreset _preset = _RangePreset.today;
  String? _kasirFilter;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final (from, to) = _rangeFor(now);
    final filter = ReportFilter(from: from, to: to, kasirId: _kasirFilter);
    final data = ref.watch(reportDataProvider(filter));
    final staff = ref.watch(staffStreamProvider);

    return ResponsiveScaffold(
      currentLocation: '/reports',
      child: Column(
        children: [
          PageHeader(
            title: 'Laporan Penjualan',
            subtitle: '${formatDate(from)} — ${formatDate(to)}',
            actions: [
              DropdownButton<_RangePreset>(
                value: _preset,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: _RangePreset.today, child: Text('Hari ini')),
                  DropdownMenuItem(value: _RangePreset.week, child: Text('7 hari terakhir')),
                  DropdownMenuItem(value: _RangePreset.month, child: Text('Bulan ini')),
                ],
                onChanged: (v) => setState(() => _preset = v ?? _RangePreset.today),
              ),
              const SizedBox(width: 8),
              staff.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (list) => DropdownButton<String?>(
                  value: _kasirFilter,
                  underline: const SizedBox.shrink(),
                  hint: const Text('Semua kasir'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Semua kasir')),
                    for (final s in list)
                      DropdownMenuItem(value: s.uid, child: Text(s.nama)),
                  ],
                  onChanged: (v) => setState(() => _kasirFilter = v),
                ),
              ),
            ],
          ),
          Expanded(
            child: data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat laporan: $e')),
              data: (report) => LayoutBuilder(
                builder: (context, constraints) {
                  final contentWidth = constraints.maxWidth > AppTheme.kContentMaxWidth
                      ? AppTheme.kContentMaxWidth
                      : constraints.maxWidth;
                  final summaryCols = contentWidth >= 1100
                      ? 4
                      : contentWidth >= 560
                          ? 2
                          : 1;
                  final sideBySide = contentWidth >= 860;
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: AppTheme.kContentMaxWidth),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          // Kartu ringkasan (responsive: 4/2/1 kolom)
                          _SummaryGrid(
                            report: report,
                            columns: summaryCols,
                            availableWidth: contentWidth - 40,
                          ),
                          const SizedBox(height: 18),
                          // Grafik
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Grafik Penjualan', style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    height: 240,
                                    child: report.revenuePerDay.isEmpty
                                        ? Center(
                                            child: Text(
                                              'Belum ada penjualan di rentang ini',
                                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                            ),
                                          )
                                        : _RevenueChart(revenuePerDay: report.revenuePerDay),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (sideBySide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _TopProductsCard(products: report.topProducts),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _PerTableCard(revenuePerTable: report.revenuePerTable),
                                ),
                              ],
                            )
                          else ...[
                            _TopProductsCard(products: report.topProducts),
                            const SizedBox(height: 14),
                            _PerTableCard(revenuePerTable: report.revenuePerTable),
                          ],
                          const SizedBox(height: 14),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Riwayat Transaksi', style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 10),
                                  if (report.transactions.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Center(
                                        child: Text(
                                          'Tidak ada transaksi',
                                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                        ),
                                      ),
                                    )
                                  else
                                    for (final t in report.transactions)
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: CircleAvatar(
                                          backgroundColor: t.sessionFinalized
                                              ? AppTheme.tableUsed.withValues(alpha: 0.12)
                                              : AppTheme.billiardGreen.withValues(alpha: 0.12),
                                          child: Icon(
                                            t.sessionFinalized
                                                ? AppTheme.billiardIcon
                                                : Icons.receipt_long_rounded,
                                            size: 20,
                                            color: t.sessionFinalized
                                                ? AppTheme.tableUsed
                                                : AppTheme.billiardGreenDark,
                                          ),
                                        ),
                                        title: Text(
                                          '${t.nomor}${t.tableName != null ? ' • Meja ${t.tableName}' : ''}',
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                        subtitle: Text(
                                          '${formatDateTime(t.createdAt)} • ${t.metodeBayar.label} • ${t.kasirNama ?? '-'}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        trailing: Text(
                                          formatRupiah(t.total),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.billiardGreenDark,
                                          ),
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  (DateTime, DateTime) _rangeFor(DateTime now) {
    switch (_preset) {
      case _RangePreset.today:
        final start = DateTime(now.year, now.month, now.day);
        return (start, start.add(const Duration(days: 1)).subtract(const Duration(seconds: 1)));
      case _RangePreset.week:
        final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        return (start, now);
      case _RangePreset.month:
        final start = DateTime(now.year, now.month, 1);
        return (start, now);
    }
  }
}

class _RevenueChart extends StatelessWidget {
  final Map<DateTime, int> revenuePerDay;

  const _RevenueChart({required this.revenuePerDay});

  @override
  Widget build(BuildContext context) {
    final days = revenuePerDay.keys.toList()..sort();
    final maxVal = revenuePerDay.values.fold<int>(0, (a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: (maxVal * 1.2).clamp(1, double.infinity),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppTheme.cardDarkHigh,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${days[groupIndex].day}/${days[groupIndex].month}\n${formatRupiah(rod.toY.toInt())}',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              getTitlesWidget: (value, meta) => Text(
                formatRupiahShort(value),
                style: TextStyle(
                    fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= days.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${days[i].day}/${days[i].month}',
                    style: TextStyle(
                    fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: revenuePerDay[days[i]]!.toDouble(),
                  color: AppTheme.billiardGreenDark,
                  width: days.length > 15 ? 8 : 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Grid kartu ringkasan responsif: 4 kolom (desktop) → 2 (tablet) → 1 (HP).
class _SummaryGrid extends StatelessWidget {
  final ReportData report;
  final int columns;
  final double availableWidth;

  const _SummaryGrid({
    required this.report,
    required this.columns,
    required this.availableWidth,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SummaryCard(
        label: 'Total Pendapatan',
        value: formatRupiah(report.totalRevenue),
        icon: Icons.payments_rounded,
        color: AppTheme.billiardGreen,
      ),
      _SummaryCard(
        label: 'Counter Sale',
        value: formatRupiah(report.counterRevenue),
        icon: Icons.shopping_bag_outlined,
        color: AppTheme.billiardGreenDark,
      ),
      _SummaryCard(
        label: 'Sesi Meja',
        value: formatRupiah(report.tableRevenue),
        icon: AppTheme.billiardIcon,
        color: AppTheme.tableUsed,
      ),
      _SummaryCard(
        label: 'Transaksi',
        value: '${report.transactions.length}',
        icon: Icons.receipt_long_rounded,
        color: AppTheme.tableReserved,
      ),
    ];

    final width = (availableWidth - 12 * (columns - 1)) / columns;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final card in cards) SizedBox(width: width, child: card),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _TopProductsCard extends StatelessWidget {
  final List<TopProduct> products;

  const _TopProductsCard({required this.products});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Produk Terlaris', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (products.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text('Belum ada data',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              )
            else
              for (var i = 0; i < products.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i < 3
                              ? AppTheme.tableReserved.withValues(alpha: 0.2)
                              : Theme.of(context).colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: i < 3
                                ? AppTheme.tableReserved
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          products[i].nama,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${products[i].qty}x',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _PerTableCard extends StatelessWidget {
  final Map<String, int> revenuePerTable;

  const _PerTableCard({required this.revenuePerTable});

  @override
  Widget build(BuildContext context) {
    final entries = revenuePerTable.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = entries.isEmpty ? 0 : entries.first.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pendapatan per Meja', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text('Belum ada data',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              )
            else
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(
                            formatRupiah(e.value),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.billiardGreenDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: maxVal == 0 ? 0 : e.value / maxVal,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade100,
                          color: AppTheme.billiardGreen,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}