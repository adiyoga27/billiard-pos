import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/billing_calculator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/responsive_scaffold.dart';
import '../../pos/providers/pos_providers.dart';
import '../../settings/domain/settings_models.dart';
import '../domain/table_models.dart';
import '../providers/tables_providers.dart';

/// Detail meja: sesi aktif, timer real-time, PESANAN MEJA (cart terpisah per
/// meja), tambah paket di tengah sesi, biaya tambahan, diskon, checkout
/// terpadu (sesi + pesanan jadi satu struk).
class TableDetailScreen extends ConsumerStatefulWidget {
  final String tableId;

  const TableDetailScreen({super.key, required this.tableId});

  @override
  ConsumerState<TableDetailScreen> createState() => _TableDetailScreenState();
}

class _TableDetailScreenState extends ConsumerState<TableDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final tables = ref.watch(tablesStreamProvider);
    final sessions = ref.watch(runningSessionsStreamProvider);
    final settings = ref.watch(settingsProvider).valueOrNull ?? const AppSettings();
    final now = ref.watch(nowTickProvider).valueOrNull ?? DateTime.now();

    return tables.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (tableList) {
        final table = tableList.where((t) => t.id == widget.tableId).firstOrNull;
        if (table == null) {
          return const Scaffold(body: Center(child: Text('Meja tidak ditemukan')));
        }
        final sessionList = sessions.valueOrNull ?? const <TableSession>[];
        final session = table.currentSessionId != null
            ? sessionList.where((s) => s.id == table.currentSessionId).firstOrNull
            : null;

        return ResponsiveScaffold(
          currentLocation: '/',
          child: Column(
            children: [
              _TableHeader(
                table: table,
                session: session,
                onReserve: () => _setReserved(!table.isAvailable),
                onStart: () => _startSession(table, settings),
                onCancel: () => _cancelSession(session!, table),
                onFinish: () => _checkoutAndFinish(session!, table),
              ),
              Expanded(
                child: session == null
                    ? _EmptyTable(table: table, now: now)
                    : _ActiveSessionView(
                        session: session,
                        table: table,
                        now: now,
                        settings: settings,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setReserved(bool reserved) async {
    final tables = ref.read(tablesStreamProvider).valueOrNull ?? const <BillTable>[];
    final table = tables.where((t) => t.id == widget.tableId).firstOrNull;
    if (table == null) return;
    await ref.read(tablesRepositoryProvider).setTableReserved(table, reserved);
  }

  Future<void> _startSession(BillTable table, AppSettings settings) async {
    await context.push('/start-session', extra: {'table': table, 'settings': settings});
  }

  /// Checkout terpadu: biaya sesi + pesanan meja → satu struk,
  /// sesi otomatis difinalisasi di dalam transaksi.
  Future<void> _checkoutAndFinish(TableSession session, BillTable table) async {
    final tableCart = ref.read(tableCartControllerProvider.notifier).cartOf(table.id);
    await context.push('/checkout', extra: {
      'items': tableCart,
      'sessionToFinalize': session,
      'title': 'Bayar Meja ${table.namaMeja}',
      'onSuccess': () {
        ref.read(tableCartControllerProvider.notifier).clearTable(table.id);
      },
    });
  }

  /// Batalkan sesi TANPA tagihan: sesi ditandai batal, meja kosong,
  /// pesanan meja & paket tambahan ikut dibatalkan.
  Future<void> _cancelSession(TableSession session, BillTable table) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Sesi?'),
        content: const Text(
          'Sesi ini akan dibatalkan TANPA tagihan.\n'
          'Pesanan meja, paket tambahan, dan biaya tambahan ikut dibatalkan. '
          'Meja akan kembali kosong.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.tableUsed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(tablesRepositoryProvider).cancelSession(session.id);
      ref.read(tableCartControllerProvider.notifier).clearTable(table.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sesi ${table.namaMeja} dibatalkan — meja kembali kosong')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membatalkan: $e')));
      }
    }
  }
}

/// Header halaman detail meja — tombol aksi jadi icon-only di layar sempit
/// supaya tidak memakan tempat di HP.
class _TableHeader extends StatelessWidget {
  final BillTable table;
  final TableSession? session;
  final VoidCallback onReserve;
  final VoidCallback onStart;
  final VoidCallback onCancel;
  final VoidCallback onFinish;

  const _TableHeader({
    required this.table,
    required this.session,
    required this.onReserve,
    required this.onStart,
    required this.onCancel,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;

    final reserveBtn = (session == null && table.status == TableStatus.kosong)
        ? (compact
            ? IconButton.outlined(
                tooltip: table.status == TableStatus.reserved ? 'Batal Reserved' : 'Reserve',
                onPressed: onReserve,
                icon: Icon(
                  table.status == TableStatus.reserved
                      ? Icons.event_available_rounded
                      : Icons.event_busy_rounded,
                  size: 20,
                ),
              )
            : OutlinedButton.icon(
                onPressed: onReserve,
                icon: Icon(
                  table.status == TableStatus.reserved
                      ? Icons.event_available_rounded
                      : Icons.event_busy_rounded,
                ),
                label: Text(table.status == TableStatus.reserved ? 'Batal Reserved' : 'Reserve'),
              ))
        : null;

    final startBtn = (session == null && table.status != TableStatus.reserved)
        ? (compact
            ? IconButton.filled(
                tooltip: 'Mulai Sesi',
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
              )
            : FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Mulai Sesi'),
              ))
        : null;

    final cancelBtn = session != null
        ? (compact
            ? IconButton.outlined(
                tooltip: 'Batalkan Sesi (tanpa tagihan)',
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined, size: 20, color: AppTheme.tableUsed),
              )
            : OutlinedButton.icon(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.tableUsed),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Batalkan Sesi'),
              ))
        : null;

    final finishBtn = session != null
        ? (compact
            ? IconButton.filled(
                tooltip: 'Selesaikan & Bayar',
                onPressed: onFinish,
                icon: const Icon(Icons.payment_rounded, size: 20),
              )
            : FilledButton.icon(
                onPressed: onFinish,
                icon: const Icon(Icons.payment_rounded),
                label: const Text('Selesaikan & Bayar'),
              ))
        : null;

    return PageHeader(
      title: table.namaMeja,
      subtitle: '${formatRupiah(table.tarifPerJam)} / jam • ${table.metodePembulatan.label}',
      actions: [
        ?reserveBtn,
        ?startBtn,
        ?cancelBtn,
        ?finishBtn,
      ],
    );
  }
}

class _EmptyTable extends ConsumerWidget {
  final BillTable table;
  final DateTime now;

  const _EmptyTable({required this.table, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(tableHistoryProvider(table.id));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.tableFree.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.check_circle_outline_rounded,
                        color: AppTheme.tableFree, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Meja kosong', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          'Tekan "Mulai Sesi" untuk mengaktifkan timer & menghitung biaya real-time.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Riwayat Pemakaian', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          history.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Center(child: Text('Gagal memuat riwayat: $e')),
            data: (sessions) {
              if (sessions.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text('Belum ada riwayat', style: TextStyle(color: Colors.grey.shade500)),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final s in sessions) _HistoryTile(session: s),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final TableSession session;

  const _HistoryTile({required this.session});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.billiardGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.history_rounded, color: AppTheme.billiardGreenDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Text(
              '${formatDateTime(session.waktuMulai)} — ${session.waktuSelesai != null ? formatClock(session.waktuSelesai!) : '?'}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              'Durasi ${session.durasiMenit ?? 0} mnt • ${session.kasirNama ?? 'Kasir'}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      session.status == SessionStatus.batal
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.tableUsed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Dibatalkan',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.tableUsed,
                ),
              ),
            )
          : Text(
              formatRupiah(session.biaya),
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.billiardGreenDark),
            ),
          ],
        ),
      ),
    );
  }
}

final tableHistoryProvider = FutureProvider.autoDispose.family<List<TableSession>, String>(
  (ref, tableId) => ref.watch(tablesRepositoryProvider).historyForTable(tableId),
);

class _ActiveSessionView extends ConsumerStatefulWidget {
  final TableSession session;
  final BillTable table;
  final DateTime now;
  final AppSettings settings;

  const _ActiveSessionView({
    required this.session,
    required this.table,
    required this.now,
    required this.settings,
  });

  @override
  ConsumerState<_ActiveSessionView> createState() => _ActiveSessionViewState();
}

class _ActiveSessionViewState extends ConsumerState<_ActiveSessionView> {
  TableSession get session => widget.session;
  BillTable get table => widget.table;
  DateTime get now => widget.now;

  Future<void> _cancelAddedPackage(
    BuildContext context,
    AddedPackage ap, {
    int totalQty = 1,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Paket?'),
        content: Text(
          '${totalQty > 1 ? '1 dari $totalQty ' : ''}${ap.namaPaket} (${formatRupiah(ap.harga)}) akan dihapus dari tagihan'
          '${ap.durasiMenit != null ? ' dan durasi ${ap.durasiMenit! ~/ 60}j ${ap.durasiMenit! % 60}m dikembalikan' : ''}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Batalkan Paket')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(tablesRepositoryProvider).removePackageFromSession(
            sessionId: session.id,
            addedPackageId: ap.id,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ap.namaPaket} dibatalkan')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membatalkan: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = session.elapsedAt(now);
    final tableCart = ref.watch(tableCartControllerProvider)[table.id] ?? const <CartItem>[];
    final orderTotal = tableCart.fold<int>(0, (acc, i) => acc + i.subtotal);
    final bill = calculateSessionBill(
      elapsed: elapsed,
      ratePerHour: table.tarifPerJam,
      mode: table.metodePembulatan,
      extraCharges: session.biayaTambahan,
      addedPackagesTotal: session.paketTambahanTotal,
      discount: session.diskon,
      flatPackagePrice: null, // paket flat: biaya final dihitung saat selesai
    );

    final overdue = session.isOverdue;

    final timerCard = Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: overdue
              ? [AppTheme.tableTimeout, AppTheme.tableUsed]
              : [AppTheme.billiardGreen, AppTheme.billiardGreenDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (overdue ? AppTheme.tableTimeout : AppTheme.billiardGreen).withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                overdue ? Icons.alarm_on_rounded : Icons.timer_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                overdue ? 'WAKTU HABIS' : 'SESI BERJALAN',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatDuration(elapsed),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 46,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (session.mode == SessionMode.durasiTetap && session.waktuSelesaiTarget != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Sisa ${formatCountdown(session.remainingUntilTarget(now))} • Target ${formatClock(session.waktuSelesaiTarget!)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Estimasi biaya', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatRupiah(bill.subtotal + orderTotal),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final infoAndActions = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoChip(icon: Icons.person_outline_rounded, label: 'Kasir: ${session.kasirNama ?? '-'}'),
            _InfoChip(
              icon: Icons.category_outlined,
              label: 'Mode: ${session.mode.label}${session.packageName != null ? ' • ${session.packageName}' : ''}',
            ),
            _InfoChip(
              icon: Icons.access_time_rounded,
              label: 'Mulai ${formatClock(session.waktuMulai)}',
            ),
            if (session.extendedMinutes > 0)
              _InfoChip(
                icon: Icons.add_circle_outline_rounded,
                label: 'Diperpanjang ${session.extendedMinutes} mnt',
                color: AppTheme.tableReserved,
              ),
            if (session.paketTambahan.isNotEmpty)
              _InfoChip(
                icon: Icons.card_giftcard_rounded,
                label: '+${session.paketTambahan.length} paket tambahan',
                color: AppTheme.tableReserved,
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Aksi sesi
        Row(
          children: [
            if (session.mode == SessionMode.durasiTetap)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/extend-form', extra: session),
                  icon: const Icon(Icons.add_alarm_rounded),
                  label: const Text('Perpanjang'),
                ),
              ),
            if (session.mode == SessionMode.durasiTetap) const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/charge-form', extra: session),
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Biaya Tambahan'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/discount-form', extra: session),
                icon: const Icon(Icons.percent_rounded),
                label: Text(session.diskon != null ? 'Ubah Diskon' : 'Diskon'),
              ),
            ),
          ],
        ),
      ],
    );

    // ===== PESANAN MEJA (cart terpisah per meja) =====
    final ordersCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.restaurant_menu_rounded, color: AppTheme.billiardGreenDark, size: 20),
                const SizedBox(width: 8),
                Text('Pesanan Meja', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text(
                  formatRupiah(orderTotal),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.billiardGreenDark),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (tableCart.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Belum ada pesanan untuk meja ini.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              )
            else
              for (final item in tableCart)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.product.nama,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _MiniQty(
                        value: item.qty,
                        onMinus: () => ref
                            .read(tableCartControllerProvider.notifier)
                            .setQty(table.id, item.product.id, item.qty - 1),
                        onPlus: () => ref
                            .read(tableCartControllerProvider.notifier)
                            .addProduct(table.id, item.product),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 90,
                        child: Text(
                          formatRupiah(item.subtotal),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/order-picker', extra: table.id),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tambah Pesanan'),
              ),
            ),
          ],
        ),
      ),
    );

    // ===== PAKET DITAMBAHKAN (beli di tengah sesi) =====
    final addedPackagesCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.card_giftcard_rounded, color: AppTheme.tableReserved, size: 20),
                const SizedBox(width: 8),
                Text('Paket Ditambahkan', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text(
                  formatRupiah(session.paketTambahanTotal),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.tableReserved),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (session.paketTambahan.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Belum ada paket tambahan. Paket bisa dibeli di tengah sesi untuk menambah durasi.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              )
            else
              for (final g in groupAddedPackages(session.paketTambahan))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.qty > 1 ? '${g.namaPaket} × ${g.qty}' : g.namaPaket,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (g.durasiMenit != null)
                              Text(
                                '+${g.durasiMenit! ~/ 60}j ${g.durasiMenit! % 60}m',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 90,
                        child: Text(
                          formatRupiah(g.subtotal),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: g.qty > 1 ? 'Batalkan 1 paket' : 'Batalkan paket',
                        onPressed: () =>
                            _cancelAddedPackage(context, g.entries.first, totalQty: g.qty),
                        icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.tableUsed),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/add-package', extra: session),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tambah Paket'),
              ),
            ),
          ],
        ),
      ),
    );

    // Breakdown biaya
    final billCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Breakdown Tagihan', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _BillRow(
              label: session.packageName != null
                  ? 'Paket ${session.packageName}'
                  : 'Sewa ${formatDurationHuman(elapsed)}',
              value: bill.rentalFee,
              bold: true,
            ),
            if (session.paketTambahan.isNotEmpty)
              _BillRow(
                label: 'Paket tambahan (${session.paketTambahan.length})',
                value: bill.addedPackagesTotal,
              ),
            if (bill.extraChargesTotal > 0)
              _BillRow(label: 'Biaya tambahan (${session.biayaTambahan.length} item)', value: bill.extraChargesTotal),
            if (bill.discountAmount > 0)
              _BillRow(
                label: 'Diskon${bill.discount?.reason != null ? ' (${bill.discount!.reason})' : ''}',
                value: -bill.discountAmount,
                color: AppTheme.tableFree,
              ),
            if (orderTotal > 0) _BillRow(label: 'Pesanan meja (${tableCart.length} item)', value: orderTotal),
            const Divider(height: 20),
            _BillRow(
              label: 'Subtotal tagihan',
              value: bill.subtotal + orderTotal,
              bold: true,
              big: true,
            ),
          ],
        ),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppTheme.kContentMaxWidth),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final left = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [timerCard, infoAndActions],
              );
              final right = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ordersCard,
                  const SizedBox(height: 16),
                  addedPackagesCard,
                  const SizedBox(height: 16),
                  billCard,
                ],
              );

              if (constraints.maxWidth >= 960) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 16),
                    Expanded(child: right),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [left, const SizedBox(height: 16), right],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MiniQty extends StatelessWidget {
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _MiniQty({required this.value, required this.onMinus, required this.onPlus});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onMinus,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.remove_rounded, size: 15),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        InkWell(
          onTap: onPlus,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppTheme.billiardGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.add_rounded, size: 15, color: AppTheme.billiardGreenDark),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color ?? AppTheme.billiardGreenDark),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final int value;
  final bool bold;
  final bool big;
  final Color? color;

  const _BillRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.big = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: big ? 16 : 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ),
          Text(
            '${value < 0 ? '-' : ''}${formatRupiah(value.abs())}',
            style: TextStyle(
              fontSize: big ? 18 : 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? AppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}