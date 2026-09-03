import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yesbilliard/features/pos/domain/product_models.dart';
import 'package:yesbilliard/features/pos/presentation/print_receipt_dialog.dart';
import 'package:yesbilliard/features/settings/domain/settings_models.dart';

/// Regression: dialog hasil transaksi = pilihan cetak Bluetooth thermal,
/// bukan preview struk langsung. Di environment test (tanpa Bluetooth)
/// harus tetap settle & menampilkan fallback.
void main() {
  final tx = Transaction(
    id: 't1',
    nomor: 'INV-1',
    kasirId: 'u1',
    kasirNama: 'Budi',
    createdAt: DateTime(2026, 9, 3, 10, 30),
    items: [
      const TransactionItem(productId: 'p1', nama: 'Nasi Goreng', qty: 2, hargaSatuan: 25000),
    ],
    subtotal: 50000,
    diskon: 0,
    pajak: 0,
    serviceCharge: 0,
    total: 50000,
    metodeBayar: PaymentMethod.tunai,
    uangDiterima: 100000,
    kembalian: 50000,
  );

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('dialog cetak: judul, info kertas, fallback preview, tombol tutup',
      (tester) async {
    var closed = false;
    await tester.pumpWidget(wrap(
      Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => PrintReceiptDialog(
                transaction: tx,
                settings: const AppSettings(),
                closeLabel: 'Transaksi Baru',
                onClose: () => closed = true,
              ),
            ),
            child: const Text('buka'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    // Judul + ringkasan
    expect(find.text('Transaksi Berhasil'), findsOneWidget);
    expect(find.text('INV-1 • Tunai'), findsOneWidget);
    expect(find.text('Total Rp 50.000'), findsOneWidget);

    // Info kertas dari settings (default 58 mm)
    expect(find.text('Kertas 58 mm'), findsOneWidget);

    // Environment test = platform Android tanpa handler izin → permintaan izin
    // gagal → UI meminta user mengaktifkan izin Bluetooth
    expect(find.text('Izin Bluetooth belum diberikan'), findsOneWidget);
    expect(find.text('Aktifkan Izin'), findsOneWidget);
    expect(find.text('Buka Pengaturan'), findsOneWidget);

    // Preview struk masih bisa dibuka
    await tester.tap(find.text('Lihat Struk (preview)'));
    await tester.pumpAndSettle();
    expect(find.text('Struk'), findsOneWidget);
    expect(find.textContaining('YES BILLIARD'), findsOneWidget);
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();

    // Tombol penutup memanggil onClose
    await tester.tap(find.text('Transaksi Baru'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
  });

  testWidgets('dialog cetak: menampilkan label kertas 80 mm dari settings',
      (tester) async {
    await tester.pumpWidget(wrap(
      Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => PrintReceiptDialog(
                transaction: tx,
                settings: const AppSettings(kertasMm: 80),
                closeLabel: 'Tutup',
              ),
            ),
            child: const Text('buka'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    expect(find.text('Kertas 80 mm'), findsOneWidget);
  });
}
