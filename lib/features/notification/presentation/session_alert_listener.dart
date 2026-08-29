import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_providers.dart';
import '../../settings/domain/settings_models.dart';
import '../../tables/domain/table_models.dart';
import '../../tables/providers/tables_providers.dart';
import '../services/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(service.stopAlarmSound);
  return service;
});

/// Listener global untuk peringatan sesi durasi tetap.
///
/// Tiap detik mengecek sesi yang `waktu_selesai_target`-nya sudah ≤ ambang
/// peringatan (default 10 menit) atau sudah lewat. Saat terdeteksi (dan
/// `is_alert_triggered` masih false), tampilkan dialog interaktif + alarm
/// suara + local notification. Sumber kebenaran ada di Firestore, jadi tetap
/// akurat walau app di-restart atau device berganti.
class SessionAlertListener extends ConsumerStatefulWidget {
  const SessionAlertListener({super.key});

  @override
  ConsumerState<SessionAlertListener> createState() => _SessionAlertListenerState();
}

class _SessionAlertListenerState extends ConsumerState<SessionAlertListener> {
  final Set<String> _shownAlerts = {};
  ProviderSubscription<AsyncValue<DateTime>>? _tickSub;

  @override
  void initState() {
    super.initState();
    // Tick global tiap detik untuk mengecek sesi yang mendekati waktu habis.
    // listenManual boleh dipakai di luar build (initState).
    _tickSub = ref.listenManual(nowTickProvider, (prev, next) {
      final now = next.valueOrNull;
      if (now != null) _checkAlerts(now);
    });
  }

  @override
  void dispose() {
    _tickSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  Future<void> _checkAlerts(DateTime now) async {
    final sessions = ref.read(runningSessionsStreamProvider).valueOrNull ?? const <TableSession>[];
    final settings = ref.read(settingsProvider).valueOrNull ?? const AppSettings();
    final tables = ref.read(tablesStreamProvider).valueOrNull ?? const <BillTable>[];
    final repo = ref.read(tablesRepositoryProvider);
    final tableMap = {for (final t in tables) t.id: t};

    for (final session in sessions) {
      if (session.mode != SessionMode.durasiTetap) continue;
      if (session.isAlertTriggered) continue;
      final target = session.waktuSelesaiTarget;
      if (target == null) continue;

      final remaining = target.difference(now);
      final threshold = Duration(minutes: settings.ambangPeringatanMenit);
      final isDue = remaining <= threshold;

      if (!isDue) continue;

      // Cegah trigger dobel di device yang sama
      if (_shownAlerts.contains(session.id)) continue;
      _shownAlerts.add(session.id);

      final tableName = tableMap[session.tableId]?.namaMeja ?? session.tableName ?? 'Meja';
      final overdue = remaining.isNegative;

      await repo.setAlertTriggered(session.id);
      final notif = ref.read(notificationServiceProvider);
      await notif.showSessionAlert(
        tableId: session.tableId,
        tableName: tableName,
        message: overdue
            ? 'Meja $tableName sudah LEWAT ${formatCountdown(remaining)}. Segera cek ke meja.'
            : 'Meja $tableName akan selesai dalam ${formatCountdown(remaining)}.',
      );

      if (mounted) {
        _showAlertDialog(
          session: session,
          tableName: tableName,
          remaining: remaining,
          settings: settings,
        );
      }
    }
  }

  void _showAlertDialog({
    required TableSession session,
    required String tableName,
    required Duration remaining,
    required AppSettings settings,
  }) {
    final notif = ref.read(notificationServiceProvider);
    final overdue = remaining.isNegative;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) notif.stopAlarmSound();
        },
        child: AlertDialog(
          title: Row(
            children: [
              Icon(
                overdue ? Icons.alarm_off_rounded : Icons.timer_off_rounded,
                color: overdue ? AppTheme.tableTimeout : AppTheme.tableReserved,
              ),
              const SizedBox(width: 10),
              Text(overdue ? 'Waktu Habis!' : 'Sesi Akan Berakhir'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Meja $tableName ${overdue ? 'sudah melewati' : 'akan selesai dalam'} ${formatCountdown(remaining)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Durasi sesi: ${formatDurationHuman(session.waktuSelesaiTarget!.difference(session.waktuMulai))}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              if (!overdue) ...[
                const SizedBox(height: 6),
                Text(
                  'Perpanjang waktu atau selesaikan sekarang.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                notif.stopAlarmSound();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Tutup'),
            ),
            if (!overdue)
              FilledButton.tonal(
                onPressed: () {
                  notif.stopAlarmSound();
                  Navigator.of(dialogContext).pop();
                  _showExtendDialog(session, tableName, settings);
                },
                child: const Text('Perpanjang Waktu'),
              ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: overdue ? AppTheme.tableTimeout : AppTheme.billiardGreen,
              ),
              onPressed: () {
                notif.stopAlarmSound();
                Navigator.of(dialogContext).pop();
                _finishSession(session);
              },
              child: const Text('Selesaikan Sekarang'),
            ),
          ],
        ),
      ),
    );
  }

  void _showExtendDialog(TableSession session, String tableName, AppSettings settings) {
    final ctrl = TextEditingController(text: '30');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Perpanjang Waktu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Berapa menit tambahan untuk meja $tableName?'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Menit tambahan',
                suffixText: 'menit',
                prefixIcon: Icon(Icons.timer_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final minutes = int.tryParse(ctrl.text) ?? 0;
              if (minutes <= 0) return;
              Navigator.of(dialogContext).pop();
              await ref
                  .read(tablesRepositoryProvider)
                  .extendSession(sessionId: session.id, additionalMinutes: minutes);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sesi $tableName diperpanjang $minutes menit')),
                );
              }
            },
            child: const Text('Perpanjang'),
          ),
        ],
      ),
    );
  }

  Future<void> _finishSession(TableSession session) async {
    final user = ref.read(currentUserProvider);
    final tables = ref.read(tablesStreamProvider).valueOrNull ?? const <BillTable>[];
    final table = tables.where((t) => t.id == session.tableId).firstOrNull;

    if (table == null || user == null) return;
    try {
      await ref.read(tablesRepositoryProvider).finishSession(
            session: session,
            ratePerHour: table.tarifPerJam,
            roundingMode: table.metodePembulatan,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sesi ${table.namaMeja} selesai — meja kembali kosong')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }
}