import 'package:esc_pos_utils/esc_pos_utils.dart';

import '../../../core/utils/formatters.dart';
import '../../settings/domain/settings_models.dart';
import '../domain/product_models.dart';

/// Membangun struk thermal (ESC/POS) + teks preview dari sebuah transaksi.
///
/// Lebar kertas mengikuti `AppSettings.kertasMm` (58 atau 80 mm).
/// Header & footer struk diambil dari pengaturan admin (tersimpan di Firebase).
class ReceiptBuilder {
  const ReceiptBuilder();

  static const _defaultFooter = 'Terima kasih, selamat bermain!';

  /// Lebar karakter per baris sesuai kertas.
  static int charWidth(int kertasMm) => kertasMm == 80 ? 48 : 32;

  String buildText({
    required Transaction transaction,
    required AppSettings settings,
    int? sessionFee,
  }) {
    final b = StringBuffer();
    final w = charWidth(settings.kertasMm);
    String center(String s) => s.padLeft((w + s.length) ~/ 2).padRight(w);
    String line(String label, String value) =>
        '${label.padRight(w - value.length)}$value';

    b.writeln(center(settings.namaToko.isEmpty ? 'YES BILLIARD' : settings.namaToko.toUpperCase()));
    if (settings.alamat.isNotEmpty) b.writeln(center(settings.alamat));
    if (settings.noTelp.isNotEmpty) b.writeln(center('Telp: ${settings.noTelp}'));
    if (settings.strukHeader.trim().isNotEmpty) {
      b.writeln('-' * w);
      for (final l in settings.strukHeader.trim().split('\n')) {
        b.writeln(center(l.trim()));
      }
    }
    b.writeln('=' * w);
    b.writeln(line('No', transaction.nomor));
    b.writeln(line('Tanggal', formatDateTime(transaction.createdAt)));
    b.writeln(line('Kasir', transaction.kasirNama ?? '-'));
    if (transaction.namaMember != null) {
      b.writeln(line('Member', transaction.namaMember!));
    }
    if (transaction.tableName != null) {
      b.writeln(line('Meja', transaction.tableName!));
    }
    b.writeln('=' * w);
    for (final item in transaction.items) {
      b.writeln(item.nama);
      b.writeln('${item.qty} x ${formatRupiah(item.hargaSatuan)}'.padRight(w - formatRupiah(item.subtotal).length) +
          formatRupiah(item.subtotal));
    }
    if (transaction.sessionFinalized && sessionFee != null && sessionFee > 0) {
      b.writeln('Sesi Billiard');
      b.writeln('Sewa meja ${transaction.tableName ?? ''}'.padRight(w - formatRupiah(sessionFee).length) +
          formatRupiah(sessionFee));
    }
    b.writeln('=' * w);
    b.writeln(line('Subtotal', formatRupiah(transaction.subtotal)));
    if (transaction.diskon > 0) b.writeln(line('Diskon', '-${formatRupiah(transaction.diskon)}'));
    if (transaction.diskonMember > 0) {
      b.writeln(line('Diskon member', '-${formatRupiah(transaction.diskonMember)}'));
    }
    if (transaction.serviceCharge > 0) b.writeln(line('Service', formatRupiah(transaction.serviceCharge)));
    if (transaction.pajak > 0) b.writeln(line('Pajak', formatRupiah(transaction.pajak)));
    b.writeln('-' * w);
    b.writeln(line('TOTAL', formatRupiah(transaction.total)));
    if (transaction.metodeBayar == PaymentMethod.tunai) {
      if (transaction.uangDiterima != null) {
        b.writeln(line('Tunai', formatRupiah(transaction.uangDiterima!)));
        b.writeln(line('Kembalian', formatRupiah(transaction.kembalian ?? 0)));
      }
    } else {
      b.writeln(line('Bayar', transaction.metodeBayar.label.toUpperCase()));
    }
    b.writeln('=' * w);
    b.writeln(center('TERIMA KASIH'));
    final footer = settings.strukFooter.trim().isEmpty
        ? _defaultFooter
        : settings.strukFooter.trim();
    for (final l in footer.split('\n')) {
      b.writeln(center(l.trim()));
    }
    b.writeln();
    b.writeln();
    return b.toString();
  }

  /// Bytes ESC/POS untuk thermal printer (58mm / 80mm sesuai settings).
  Future<List<int>> buildEscBytes({
    required Transaction transaction,
    required AppSettings settings,
    int? sessionFee,
  }) async {
    final profile = await CapabilityProfile.load();
    final paper = settings.kertasMm == 80 ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paper, profile);
    var bytes = <int>[];

    bytes += generator.text(
      settings.namaToko.isEmpty ? 'YES BILLIARD' : settings.namaToko,
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );
    if (settings.alamat.isNotEmpty) {
      bytes += generator.text(settings.alamat, styles: const PosStyles(align: PosAlign.center));
    }
    if (settings.noTelp.isNotEmpty) {
      bytes += generator.text('Telp: ${settings.noTelp}', styles: const PosStyles(align: PosAlign.center));
    }
    if (settings.strukHeader.trim().isNotEmpty) {
      bytes += generator.hr();
      for (final l in settings.strukHeader.trim().split('\n')) {
        bytes += generator.text(l.trim(), styles: const PosStyles(align: PosAlign.center));
      }
    }
    bytes += generator.hr();
    bytes += generator.text('No: ${transaction.nomor}');
    bytes += generator.text('Tanggal: ${formatDateTime(transaction.createdAt)}');
    bytes += generator.text('Kasir: ${transaction.kasirNama ?? '-'}');
    if (transaction.namaMember != null) {
      bytes += generator.text('Member: ${transaction.namaMember}');
    }
    if (transaction.tableName != null) {
      bytes += generator.text('Meja: ${transaction.tableName}');
    }
    bytes += generator.hr();
    for (final item in transaction.items) {
      // Nama item di baris sendiri (bold), lalu baris qty x harga — total
      // rata kanan. Kolom 7+5 = 12 unit: cukup lebar supaya harga tidak
      // terpotong/terlipat (sebelumnya kolom harga cuma 2 unit → tulisan
      // jadi tidak lurus).
      bytes += generator.text(item.nama, styles: const PosStyles(bold: true));
      bytes += generator.row([
        PosColumn(
          text: '${item.qty} x ${formatRupiah(item.hargaSatuan)}',
          width: 7,
        ),
        PosColumn(
          text: formatRupiah(item.subtotal),
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    if (transaction.sessionFinalized && sessionFee != null && sessionFee > 0) {
      bytes += generator.text('Sesi Billiard (${transaction.tableName ?? ''})',
          styles: const PosStyles(bold: true));
      bytes += generator.row([
        PosColumn(text: 'Sewa meja', width: 7),
        PosColumn(
          text: formatRupiah(sessionFee),
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'Subtotal', width: 7),
      PosColumn(
        text: formatRupiah(transaction.subtotal),
        width: 5,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    if (transaction.diskon > 0) {
      bytes += generator.row([
        PosColumn(text: 'Diskon', width: 7),
        PosColumn(
          text: '-${formatRupiah(transaction.diskon)}',
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    if (transaction.diskonMember > 0) {
      bytes += generator.row([
        PosColumn(text: 'Diskon member', width: 7),
        PosColumn(
          text: '-${formatRupiah(transaction.diskonMember)}',
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    if (transaction.serviceCharge > 0) {
      bytes += generator.row([
        PosColumn(text: 'Service', width: 7),
        PosColumn(
          text: formatRupiah(transaction.serviceCharge),
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    if (transaction.pajak > 0) {
      bytes += generator.row([
        PosColumn(text: 'Pajak', width: 7),
        PosColumn(
          text: formatRupiah(transaction.pajak),
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 7, styles: const PosStyles(bold: true)),
      PosColumn(
        text: formatRupiah(transaction.total),
        width: 5,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    if (transaction.uangDiterima != null) {
      bytes += generator.row([
        PosColumn(text: 'Tunai', width: 7),
        PosColumn(
          text: formatRupiah(transaction.uangDiterima!),
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Kembalian', width: 7),
        PosColumn(
          text: formatRupiah(transaction.kembalian ?? 0),
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    } else {
      bytes += generator.row([
        PosColumn(text: 'Bayar', width: 7),
        PosColumn(
          text: transaction.metodeBayar.label,
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    bytes += generator.hr();
    bytes += generator.text('TERIMA KASIH', styles: const PosStyles(align: PosAlign.center, bold: true));
    final footer = settings.strukFooter.trim().isEmpty
        ? _defaultFooter
        : settings.strukFooter.trim();
    for (final l in footer.split('\n')) {
      bytes += generator.text(l.trim(), styles: const PosStyles(align: PosAlign.center));
    }
    bytes += generator.feed(2);
    bytes += generator.cut();
    return bytes;
  }
}
