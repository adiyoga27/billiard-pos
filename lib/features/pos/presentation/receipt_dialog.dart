import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../settings/domain/settings_models.dart';
import '../domain/product_models.dart';
import 'receipt_builder.dart';

/// Preview struk setelah transaksi sukses (+ tombol cetak/salin/lihat detail).
class ReceiptDialog extends ConsumerWidget {
  final Transaction transaction;
  final AppSettings settings;

  const ReceiptDialog({super.key, required this.transaction, required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = const ReceiptBuilder().buildText(
      transaction: transaction,
      settings: settings,
    );

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.tableFree, size: 26),
          const SizedBox(width: 10),
          const Text('Transaksi Berhasil'),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${transaction.nomor} • ${transaction.metodeBayar.label}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              Text(
                'Total ${formatRupiah(transaction.total)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: AppTheme.billiardGreenDark, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  text,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Struk disalin ke clipboard')),
              );
            }
          },
          child: const Text('Salin Struk'),
        ),
        TextButton(
          onPressed: () => context.push('/transaction/${transaction.nomor}'),
          child: const Text('Detail'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            context.go('/pos');
          },
          child: const Text('Transaksi Baru'),
        ),
      ],
    );
  }
}