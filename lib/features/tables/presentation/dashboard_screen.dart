
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/billing_calculator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/responsive_scaffold.dart';
import '../../notification/presentation/session_alert_listener.dart';
import '../../pos/providers/pos_providers.dart';
import '../../settings/domain/settings_models.dart';
import '../domain/table_models.dart';
import '../providers/tables_providers.dart';

/// Dashboard utama: grid kartu status semua meja + shortcut POS.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tablesStreamProvider);
    final sessions = ref.watch(runningSessionsStreamProvider);
    final cart = ref.watch(cartControllerProvider);
    final compact = MediaQuery.sizeOf(context).width < 600;

    return ResponsiveScaffold(
      currentLocation: '/',
      child: Column(
        children: [
          const SessionAlertListener(),
          PageHeader(
            title: 'Status Meja',
            subtitle: 'Update real-time dari semua device kasir',
            actions: [
              if (cart.itemCount > 0)
                compact
                    ? Badge(
                        label: Text('${cart.itemCount}'),
                        child: IconButton.filledTonal(
                          tooltip: 'Buka Kasir',
                          onPressed: () => context.go('/pos'),
                          icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                        ),
                      )
                    : FilledButton.tonalIcon(
                        onPressed: () => context.go('/pos'),
                        icon: Badge(
                          label: Text('${cart.itemCount}'),
                          child: const Icon(Icons.shopping_cart_outlined, size: 20),
                        ),
                        label: const Text('Kasir'),
                      ),
              compact
                  ? IconButton.filled(
                      tooltip: 'Buka Kasir',
                      onPressed: () => context.go('/pos'),
                      icon: const Icon(Icons.point_of_sale_rounded, size: 20),
                    )
                  : FilledButton.icon(
                      onPressed: () => context.go('/pos'),
                      icon: const Icon(Icons.point_of_sale_rounded, size: 20),
                      label: const Text('Buka Kasir'),
                    ),
            ],
          ),
          Expanded(
            child: tables.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat meja: $e')),
              data: (tableList) {
                final running = sessions.valueOrNull ?? const <TableSession>[];
                final sessionMap = {for (final s in running) s.tableId: s};
                final now = ref.watch(nowTickProvider).valueOrNull ?? DateTime.now();
                final settings = ref.watch(settingsProvider).valueOrNull ?? const AppSettings();

                return RefreshIndicator(
                  onRefresh: () async {},
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 1200
                          ? 4
                          : constraints.maxWidth >= 800
                              ? 3
                              : constraints.maxWidth >= 480
                                  ? 2
                                  : 1;
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: AppTheme.kContentMaxWidth),
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: crossAxisCount >= 3 ? 1.3 : 1.15,
                            ),
                            itemCount: tableList.length,
                            itemBuilder: (context, i) {
                              final table = tableList[i];
                              final session = sessionMap[table.id];
                              return _TableCard(
                                table: table,
                                session: session,
                                now: now,
                                settings: settings,
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TableCard extends ConsumerWidget {
  final BillTable table;
  final TableSession? session;
  final DateTime now;
  final AppSettings settings;

  const _TableCard({
    required this.table,
    required this.session,
    required this.now,
    required this.settings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = session != null && session!.isRunning;
    final reserved = table.status == TableStatus.reserved;
    final orderCount = ref.watch(tableCartControllerProvider)[table.id]?.length ?? 0;

    Color statusColor = AppTheme.tableFree;
    String statusLabel = 'Kosong';

    if (reserved) {
      statusColor = AppTheme.tableReserved;
      statusLabel = 'Reserved';
    } else if (running) {
      final overdue = session!.isOverdue;
      statusColor = overdue ? AppTheme.tableTimeout : AppTheme.tableUsed;
      statusLabel = overdue ? 'Waktu Habis' : 'Terpakai';
    }

    final bill = running
        ? calculateSessionBill(
            elapsed: session!.elapsedAt(now),
            ratePerHour: table.tarifPerJam,
            mode: table.metodePembulatan,
            extraCharges: session!.biayaTambahan,
            discount: session!.diskon,
            flatPackagePrice: null,
          )
        : null;

    final elapsed = running ? session!.elapsedAt(now) : Duration.zero;
    final showTimeoutPulse = running && session!.isOverdue;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.push('/table/${table.id}'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: showTimeoutPulse ? AppTheme.tableTimeout : statusColor.withValues(alpha: 0.55),
            width: showTimeoutPulse ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    running ? Icons.play_arrow_rounded : AppTheme.billiardIcon,
                    color: statusColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        table.namaMeja,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.ink),
                      ),
                      Text(
                        '${formatRupiah(table.tarifPerJam)} / jam',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showTimeoutPulse) ...[
                        const Icon(Icons.notifications_active_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: showTimeoutPulse ? Colors.white : statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (running) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⏱ ${formatDuration(elapsed)}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
                        ),
                        if (session!.mode == SessionMode.durasiTetap && session!.waktuSelesaiTarget != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Sisa: ${formatCountdown(session!.remainingUntilTarget(now))}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: session!.isOverdue ? AppTheme.tableTimeout : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Estimasi',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                      Text(
                        formatRupiah(bill!.subtotal),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.billiardGreenDark),
                      ),
                    ],
                  ),
                ],
              ),
if (session!.packageName != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.billiardGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '📦 ${session!.packageName}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.billiardGreenDark),
                  ),
                ),
              ],
              if (orderCount > 0) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.tableReserved.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.restaurant_menu_rounded, size: 12, color: AppTheme.tableReserved),
                      const SizedBox(width: 4),
                      Text(
                        '$orderCount item pesanan',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.tableReserved),
                      ),
                    ],
                  ),
                ),
              ],
            ] else if (reserved) ...[
              Row(
                children: [
                  const Icon(Icons.event_available_rounded, size: 16, color: AppTheme.tableReserved),
                  const SizedBox(width: 6),
                  Text('Menunggu dimulai', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
              const Spacer(),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppTheme.tableFree),
                  const SizedBox(width: 6),
                  Text('Siap digunakan', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
              const Spacer(),
            ],
          ],
        ),
      ),
    );
  }
}