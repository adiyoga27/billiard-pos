import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:yesbilliard/features/pos/domain/product_models.dart';
import 'package:yesbilliard/features/pos/presentation/receipt_builder.dart';
import 'package:yesbilliard/features/pos/services/thermal_print_service.dart';
import 'package:yesbilliard/features/settings/domain/settings_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tx = Transaction(
    id: 't1',
    nomor: 'INV-101',
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

  group('AppSettings kertas & struk', () {
    test('round-trip fromMap/toMap', () {
      const s = AppSettings(kertasMm: 80, strukHeader: 'PROMO', strukFooter: 'IG @yesbilliard');
      final restored = AppSettings.fromMap(s.toMap());
      expect(restored.kertasMm, 80);
      expect(restored.strukHeader, 'PROMO');
      expect(restored.strukFooter, 'IG @yesbilliard');
    });

    test('kertas invalid disimpan sebagai 58 (default)', () {
      final s = AppSettings.fromMap({'kertas_mm': 999});
      expect(s.kertasMm, 58);
      final s2 = AppSettings.fromMap({'kertas_mm': '80'}); // string tetap terbaca
      expect(s2.kertasMm, 80);
    });
  });

  group('ReceiptBuilder', () {
    test('teks struk 58mm lebih sempit dari 80mm', () {
      const b = ReceiptBuilder();
      final t58 = b.buildText(transaction: tx, settings: const AppSettings(kertasMm: 58));
      final t80 = b.buildText(transaction: tx, settings: const AppSettings(kertasMm: 80));
      // Lebar baris separator: 32 char (58mm) vs 48 char (80mm)
      expect(t58.split('\n')[4].length, 32);
      expect(t80.split('\n')[4].length, 48);
    });

    test('header & footer dari settings muncul di struk teks', () {
      const b = ReceiptBuilder();
      final text = b.buildText(
        transaction: tx,
        settings: const AppSettings(strukHeader: 'PROMO SPESIAL', strukFooter: 'IG @yesbilliard'),
      );
      expect(text, contains('PROMO SPESIAL'));
      expect(text, contains('IG @yesbilliard'));
    });

    test('footer default tetap tampil bila kosong', () {
      const b = ReceiptBuilder();
      final text = b.buildText(transaction: tx, settings: const AppSettings());
      expect(text, contains('Terima kasih, selamat bermain!'));
    });

    test('bytes ESC/POS memuat header & footer (ASCII)', () async {
      const b = ReceiptBuilder();
      final bytes = await b.buildEscBytes(
        transaction: tx,
        settings: const AppSettings(strukHeader: 'PROMO', strukFooter: 'MAKASIH'),
      );
      expect(bytes, isNotEmpty);
      final asText = String.fromCharCodes(bytes.where((c) => c >= 32 && c < 127));
      expect(asText, contains('PROMO'));
      expect(asText, contains('MAKASIH'));
      expect(asText, contains('INV-101'));
    });

    test('bytes ESC/POS: harga rata kanan di ujung baris (tidak terlipat)',
        () async {
      const b = ReceiptBuilder();
      final bytes = await b.buildEscBytes(
        transaction: tx,
        settings: const AppSettings(kertasMm: 58),
      );
      final lines = latin1
          .decode(bytes, allowInvalid: true)
          .split('\n')
          .map((l) => l.trimRight())
          .toList();
      // Subtotal item 2x25.000 = 50.000 di ujung kanan barisnya
      expect(lines.any((l) => l.endsWith('Rp 50.000') && !l.contains('Tunai') && !l.contains('Kembalian')), isTrue);
      // Baris qty x harga masih utuh (tidak terpotong ke baris berikut)
      expect(lines.any((l) => l.contains('2 x Rp 25.000')), isTrue);
      // TOTAL memuat nilai total
      expect(lines.any((l) => l.contains('TOTAL') && l.endsWith('Rp 50.000')), isTrue);
    });
  });

  group('Filter perangkat printer', () {
    test('nama headset/HP/hape tidak lolos sebagai printer', () {
      expect(ThermalPrintService.isNonPrinterDevice('JBL T450 Headset'), isTrue);
      expect(ThermalPrintService.isNonPrinterDevice('TWS Airdots'), isTrue);
      expect(ThermalPrintService.isNonPrinterDevice('Samsung Galaxy A54'), isTrue);
      expect(ThermalPrintService.isNonPrinterDevice('Xiaomi Redmi Note'), isTrue);
      expect(ThermalPrintService.isNonPrinterDevice('MIX 2 Speaker'), isTrue);
    });

    test('nama printer thermal lolos', () {
      expect(ThermalPrintService.isNonPrinterDevice('MPT-II Printer'), isFalse);
      expect(ThermalPrintService.isNonPrinterDevice('HPRT N41'), isFalse);
      expect(ThermalPrintService.isNonPrinterDevice('Epson TM-T82'), isFalse);
      expect(ThermalPrintService.looksLikePrinter('MPT-II Printer'), isTrue);
      expect(ThermalPrintService.looksLikePrinter('Epson TM-T82'), isTrue);
    });
  });
}
