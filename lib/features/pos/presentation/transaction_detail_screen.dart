import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../settings/domain/settings_models.dart';
import '../../settings/providers/settings_providers.dart';
import '../domain/product_models.dart';
import '../presentation/receipt_builder.dart';
import '../providers/pos_providers.dart';
import 'package:go_router/go_router.dart';

/// Detail transaksi — halaman target deep-link `/transaction/:invoiceId`
/// (contoh dari notifikasi FCM payload `{"route": "/transaction/INV-20260901025"}`).
class TransactionDetailScreen extends ConsumerWidget {
  final String invoiceId;

  const TransactionDetailScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txFuture = ref.watch(transactionByNomorProvider(invoiceId));
    final settings = ref.watch(settingsProvider).valueOrNull ?? const AppSettings();

    return txFuture.when(
      loading: () => Scaffold(body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Gagal memuat transaksi: $e'))),
      data: (tx) {
        if (tx == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  const Text('Transaksi tidak ditemukan'),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: () => context.go('/pos'), child: const Text('Ke Kasir')),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(tx.nomor)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.receipt_long_rounded, color: AppTheme.billiardGreenDark),
                                const SizedBox(width: 8),
                                Text(tx.nomor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.billiardGreen.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    tx.metodeBayar.label,
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.billiardGreenDark, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              formatDateTime(tx.createdAt),
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            Text(
                              'Kasir: ${tx.kasirNama ?? '-'}${tx.tableName != null ? ' • Meja ${tx.tableName}' : ''}',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            if (tx.namaMember != null)
                              Text(
                                'Member: ${tx.namaMember}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Item', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 10),
                            for (final item in tx.items)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item.nama} (${item.qty}x)',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Text(
                                      formatRupiah(item.subtotal),
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            if (tx.sessionFinalized && tx.tableName != null) ...[
                              const Divider(height: 20),
                              Row(
                                children: [
                                  const Icon(AppTheme.billiardIcon, size: 18, color: AppTheme.billiardGreenDark),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Sesi meja ${tx.tableName} (final)',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            _Row('Subtotal', formatRupiah(tx.subtotal)),
                            if (tx.diskon > 0) _Row('Diskon', '-${formatRupiah(tx.diskon)}', color: AppTheme.tableFree),
                            if (tx.diskonMember > 0)
                              _Row('Diskon member', '-${formatRupiah(tx.diskonMember)}', color: AppTheme.tableFree),
                            if (tx.serviceCharge > 0) _Row('Service charge', formatRupiah(tx.serviceCharge)),
                            if (tx.pajak > 0) _Row('Pajak', formatRupiah(tx.pajak)),
                            const Divider(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('TOTAL', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                                Text(
                                  formatRupiah(tx.total),
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.billiardGreenDark),
                                ),
                              ],
                            ),
                            if (tx.uangDiterima != null) ...[
                              const SizedBox(height: 8),
                              _Row('Tunai', formatRupiah(tx.uangDiterima!)),
                              _Row('Kembalian', formatRupiah(tx.kembalian ?? 0), color: AppTheme.tableFree),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => _showReceipt(context, tx, settings),
                      icon: const Icon(Icons.print_rounded),
                      label: const Text('Lihat Struk'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showReceipt(BuildContext context, Transaction tx, AppSettings settings) {
    final text = const ReceiptBuilder().buildText(transaction: tx, settings: settings);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Struk'),
        content: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              text,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, height: 1.35),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}

final transactionByNomorProvider =
    FutureProvider.autoDispose.family<Transaction?, String>((ref, nomor) {
  return ref.watch(posRepositoryProvider).transactionByNomor(nomor);
});

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Row(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color ?? Colors.grey.shade700)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}