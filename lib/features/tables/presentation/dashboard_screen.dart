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
              loading: () => const _DashboardLoading(),
              error: (e, _) => _DashboardError(message: '$e'),
              data: (tableList) {
                final running = sessions.valueOrNull ?? const <TableSession>[];
                final sessionMap = {for (final s in running) s.tableId: s};
                final now = ref.watch(nowTickProvider).valueOrNull ?? DateTime.now();
                final settings = ref.watch(settingsProvider).valueOrNull ?? const AppSettings();

                if (tableList.isEmpty) {
                  return const _DashboardEmpty();
                }

                final counts = _StatusCounts(
                  free: tableList
                      .where((t) =>
                          t.status != TableStatus.reserved &&
                          !(sessionMap[t.id]?.isRunning ?? false))
                      .length,
                  running: tableList
                      .where((t) => sessionMap[t.id]?.isRunning ?? false)
                      .length,
                  overdue: tableList
                      .where((t) =>
                          (sessionMap[t.id]?.isRunning ?? false) &&
                          (sessionMap[t.id]?.isOverdue ?? false))
                      .length,
                  reserved:
                      tableList.where((t) => t.status == TableStatus.reserved).length,
                );

                return RefreshIndicator(
                  onRefresh: () async {},
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final crossAxisCount = width >= 1400
                          ? 5
                          : width >= 1100
                              ? 4
                              : width >= 800
                                  ? 3
                                  : width >= 480
                                      ? 2
                                      : 1;
                      final horizontalPadding = width >= 800 ? 24.0 : 16.0;

                      return Center(
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: AppTheme.kContentMaxWidth),
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            slivers: [
                              SliverPadding(
                                padding: EdgeInsets.fromLTRB(
                                    horizontalPadding, 12, horizontalPadding, 4),
                                sliver: SliverToBoxAdapter(
                                  child: _StatusSummaryBar(counts: counts),
                                ),
                              ),
                              SliverPadding(
                                padding: EdgeInsets.fromLTRB(
                                    horizontalPadding, 8, horizontalPadding, 24),
                                sliver: SliverGrid(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    mainAxisSpacing: 14,
                                    crossAxisSpacing: 14,
                                    childAspectRatio: crossAxisCount >= 3 ? 1.3 : 1.15,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, i) {
                                      final table = tableList[i];
                                      final session = sessionMap[table.id];
                                      return _TableCard(
                                        table: table,
                                        session: session,
                                        now: now,
                                        settings: settings,
                                      );
                                    },
                                    childCount: tableList.length,
                                  ),
                                ),
                              ),
                            ],
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

/// Ringkasan jumlah meja per status, ditampilkan sebagai baris chip di atas grid.
class _StatusCounts {
  final int free;
  final int running;
  final int overdue;
  final int reserved;

  const _StatusCounts({
    required this.free,
    required this.running,
    required this.overdue,
    required this.reserved,
  });
}

class _StatusSummaryBar extends StatelessWidget {
  final _StatusCounts counts;

  const _StatusSummaryBar({required this.counts});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _SummaryChip(
        label: 'Kosong',
        count: counts.free,
        color: AppTheme.tableFree,
        icon: Icons.check_circle_outline_rounded,
      ),
      _SummaryChip(
        label: 'Terpakai',
        count: counts.running,
        color: AppTheme.tableUsed,
        icon: Icons.play_circle_fill_rounded,
      ),
      _SummaryChip(
        label: 'Waktu Habis',
        count: counts.overdue,
        color: AppTheme.tableTimeout,
        icon: Icons.notifications_active_rounded,
      ),
      _SummaryChip(
        label: 'Reserved',
        count: counts.reserved,
        color: AppTheme.tableReserved,
        icon: Icons.event_available_rounded,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            chips[i],
          ],
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.10) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.35) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: active ? color : Colors.grey.shade400),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: active ? AppTheme.ink : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? Colors.grey.shade700 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableCard extends ConsumerStatefulWidget {
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
  ConsumerState<_TableCard> createState() => _TableCardState();
}

class _TableCardState extends ConsumerState<_TableCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final table = widget.table;
    final session = widget.session;
    final now = widget.now;

    final running = session != null && session.isRunning;
    final reserved = table.status == TableStatus.reserved;
    final orderCount = ref.watch(tableCartControllerProvider)[table.id]?.length ?? 0;

    Color statusColor = AppTheme.tableFree;
    String statusLabel = 'Kosong';
    IconData statusIcon = Icons.check_circle_outline_rounded;

    if (reserved) {
      statusColor = AppTheme.tableReserved;
      statusLabel = 'Reserved';
      statusIcon = Icons.event_available_rounded;
    } else if (running) {
      final overdue = session.isOverdue;
      statusColor = overdue ? AppTheme.tableTimeout : AppTheme.tableUsed;
      statusLabel = overdue ? 'Waktu Habis' : 'Terpakai';
      statusIcon = overdue ? Icons.notifications_active_rounded : Icons.play_circle_fill_rounded;
    }

    final bill = running
        ? calculateSessionBill(
            elapsed: session.elapsedAt(now),
            ratePerHour: table.tarifPerJam,
            mode: table.metodePembulatan,
            extraCharges: session.biayaTambahan,
            discount: session.diskon,
            flatPackagePrice: null,
          )
        : null;

    final elapsed = running ? session.elapsedAt(now) : Duration.zero;
    final showTimeoutPulse = running && session.isOverdue;

    double? progress;
    if (running &&
        session.mode == SessionMode.durasiTetap &&
        session.waktuSelesaiTarget != null) {
      final remaining = session.remainingUntilTarget(now);
      final total = elapsed + (remaining.isNegative ? Duration.zero : remaining);
      if (total.inSeconds > 0) {
        progress = (elapsed.inSeconds / total.inSeconds).clamp(0.0, 1.0);
      }
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulse = showTimeoutPulse ? _pulseController.value : 0.0;
          final glowBlur = showTimeoutPulse ? 16 + (pulse * 10) : 14.0;

          return AnimatedScale(
            scale: _hovering ? 1.015 : 1.0,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: _hovering ? 0.20 : 0.12),
                    blurRadius: glowBlur,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.push('/table/${table.id}'),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final pulse = showTimeoutPulse ? _pulseController.value : 0.0;
                final borderAlpha = showTimeoutPulse ? 0.55 + (pulse * 0.45) : 0.45;

                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        Color.alphaBlend(
                          statusColor.withValues(alpha: running || reserved ? 0.05 : 0.0),
                          Colors.white,
                        ),
                      ],
                    ),
                    border: Border.all(
                      color: statusColor.withValues(alpha: borderAlpha),
                      width: showTimeoutPulse ? 2.2 : 1.4,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  statusColor.withValues(alpha: 0.20),
                                  statusColor.withValues(alpha: 0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.ink,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${formatRupiah(table.tarifPerJam)} / jam',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusPill(
                            label: statusLabel,
                            color: statusColor,
                            icon: statusIcon,
                            emphasize: showTimeoutPulse,
                            pulseValue: pulse,
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
                                  Row(
                                    children: [
                                      Icon(Icons.schedule_rounded,
                                          size: 16, color: Colors.grey.shade500),
                                      const SizedBox(width: 4),
                                      Text(
                                        formatDuration(elapsed),
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          fontFeatures: [FontFeature.tabularFigures()],
                                          height: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (session.mode == SessionMode.durasiTetap &&
                                      session.waktuSelesaiTarget != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Sisa ${formatCountdown(session.remainingUntilTarget(now))}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: session.isOverdue
                                            ? AppTheme.tableTimeout
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Estimasi',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                                Text(
                                  formatRupiah(bill!.subtotal),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.billiardGreenDark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (progress != null) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 5,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation(statusColor),
                            ),
                          ),
                        ],
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (session.packageName != null)
                              _MetaTag(
                                icon: Icons.inventory_2_rounded,
                                label: session.packageName!,
                                color: AppTheme.billiardGreenDark,
                              ),
                            if (orderCount > 0)
                              _MetaTag(
                                icon: Icons.restaurant_menu_rounded,
                                label: '$orderCount item pesanan',
                                color: AppTheme.tableReserved,
                              ),
                          ],
                        ),
                      ] else if (reserved) ...[
                        Row(
                          children: [
                            Icon(Icons.event_available_rounded,
                                size: 16, color: AppTheme.tableReserved),
                            const SizedBox(width: 6),
                            Text('Menunggu dimulai',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded,
                                size: 16, color: AppTheme.tableFree),
                            const SizedBox(width: 6),
                            Text('Siap digunakan',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool emphasize;
  final double pulseValue;

  const _StatusPill({
    required this.label,
    required this.color,
    required this.icon,
    required this.emphasize,
    required this.pulseValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: emphasize
            ? color.withValues(alpha: 0.85 + (pulseValue * 0.15))
            : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: emphasize ? Colors.white : color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: emphasize ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaTag({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  final String message;

  const _DashboardError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Gagal memuat meja',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardEmpty extends StatelessWidget {
  const _DashboardEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.billiardGreen.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(AppTheme.billiardIcon, size: 30, color: AppTheme.billiardGreenDark),
            ),
            const SizedBox(height: 14),
            const Text(
              'Belum ada meja',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.ink),
            ),
            const SizedBox(height: 4),
            Text(
              'Tambahkan meja pertama untuk mulai memantau status secara real-time.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}