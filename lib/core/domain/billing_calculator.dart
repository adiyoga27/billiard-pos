/// Perhitungan biaya sewa meja billiard.
///
/// SELURUH logika biaya berjalan ada di file ini sebagai PURE FUNCTION
/// supaya mudah di-unit test dan tidak bergantung pada state UI.
/// Dipakai bersama oleh modul Meja Billiard & POS.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Mode pembulatan waktu sewa.
enum RoundingMode { perMinute, per15Minutes, perHour }

extension RoundingModeX on RoundingMode {
  String get label => switch (this) {
        RoundingMode.perMinute => 'Per menit',
        RoundingMode.per15Minutes => 'Per 15 menit',
        RoundingMode.perHour => 'Per jam penuh',
      };

  String get storageValue => switch (this) {
        RoundingMode.perMinute => 'per_menit',
        RoundingMode.per15Minutes => 'per_15_menit',
        RoundingMode.perHour => 'per_jam',
      };

  static RoundingMode fromStorage(String? v) => switch (v) {
        'per_15_menit' => RoundingMode.per15Minutes,
        'per_jam' => RoundingMode.perHour,
        _ => RoundingMode.perMinute,
      };
}

/// Tipe diskon — dipakai konsisten antara sesi meja & transaksi POS.
enum DiscountType { percent, nominal }

extension DiscountTypeX on DiscountType {
  String get label => this == DiscountType.percent ? 'Persen (%)' : 'Nominal (Rp)';

  String get storageValue => this == DiscountType.percent ? 'persen' : 'nominal';

  static DiscountType fromStorage(String? v) => v == 'persen' ? DiscountType.percent : DiscountType.nominal;
}

/// Diskriminasi diskon sesi/transaksi.
class Discount {
  final DiscountType type;
  final int value;
  final String? reason;

  const Discount({required this.type, required this.value, this.reason});

  int get amount => value;

  factory Discount.fromMap(Map<String, dynamic> map) => Discount(
        type: DiscountTypeX.fromStorage(map['tipe'] as String?),
        value: (map['nilai'] as num?)?.toInt() ?? 0,
        reason: map['alasan'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'tipe': type.storageValue,
        'nilai': value,
        if (reason != null && reason!.isNotEmpty) 'alasan': reason,
      };
}

/// Pembulatan ke atas ke kelipatan [step].
int roundUpTo(int value, int step) => ((value + step - 1) ~/ step) * step;

/// Jumlah menit yang DITAGIH berdasarkan mode pembulatan.
/// Minimal ditagih 1 blok (1 mnt / 15 mnt / 60 mnt) supaya tidak gratis.
int billedMinutes(Duration elapsed, RoundingMode mode) {
  final minutes = elapsed.inMinutes < 1 ? 1 : elapsed.inMinutes;
  return switch (mode) {
    RoundingMode.perMinute => minutes,
    RoundingMode.per15Minutes => roundUpTo(minutes, 15),
    RoundingMode.perHour => roundUpTo(minutes, 60),
  };
}

/// Biaya sewa berjalan (running cost) untuk tarif per jam normal.
/// Tarif per jam dibagi rata ke menit tagihan; hasil dibulatkan ke rupiah penuh.
int rentalCost({
  required Duration elapsed,
  required int ratePerHour,
  required RoundingMode mode,
}) {
  if (ratePerHour <= 0) return 0;
  final minutes = billedMinutes(elapsed, mode);
  final perMinute = ratePerHour / 60.0;
  return (minutes * perMinute).round();
}

/// Biaya tambahan dinamis selama sesi (sewa stik premium, ganti bola, dsb).
class ExtraCharge {
  final String nama;
  final int jumlah;
  final int hargaSatuan;
  final String ditambahkanOleh;
  final DateTime waktuDitambahkan;

  const ExtraCharge({
    required this.nama,
    required this.jumlah,
    required this.hargaSatuan,
    required this.ditambahkanOleh,
    required this.waktuDitambahkan,
  });

  int get subtotal => jumlah * hargaSatuan;

  factory ExtraCharge.fromMap(Map<String, dynamic> map) {
    final raw = map['waktu_ditambahkan'];
    return ExtraCharge(
      nama: map['nama'] as String? ?? '',
      jumlah: (map['jumlah'] as num?)?.toInt() ?? 1,
      hargaSatuan: (map['harga_satuan'] as num?)?.toInt() ?? 0,
      ditambahkanOleh: map['ditambahkan_oleh'] as String? ?? '',
      waktuDitambahkan: raw is Timestamp
          ? raw.toDate()
          : raw is DateTime
              ? raw
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'nama': nama,
        'jumlah': jumlah,
        'harga_satuan': hargaSatuan,
        'subtotal': subtotal,
        'ditambahkan_oleh': ditambahkanOleh,
        'waktu_ditambahkan': Timestamp.fromDate(waktuDitambahkan),
      };
}

/// Jumlah diskon dalam rupiah dari sebuah subtotal.
/// Dibatasi agar tidak melebihi subtotal (tidak minus).
int discountAmount(int subtotal, Discount? discount) {
  if (discount == null || subtotal <= 0) return 0;
  final raw = discount.type == DiscountType.percent
      ? (subtotal * discount.value / 100).round()
      : discount.value;
  return raw.clamp(0, subtotal);
}

/// Breakdown tagihan akhir sesi meja:
/// `biaya sewa waktu (atau harga paket flat) + biaya tambahan + paket tambahan − diskon = subtotal sesi`
class SessionBill {
  final int rentalFee; // biaya sewa waktu berjalan / harga paket flat pertama
  final int extraChargesTotal;
  final int addedPackagesTotal; // paket yang dibeli saat sesi berjalan
  final Discount? discount;
  final int discountAmount;
  final int subtotal;

  const SessionBill({
    required this.rentalFee,
    required this.extraChargesTotal,
    required this.addedPackagesTotal,
    required this.discount,
    required this.discountAmount,
    required this.subtotal,
  });
}

SessionBill calculateSessionBill({
  required Duration elapsed,
  required int ratePerHour,
  required RoundingMode mode,
  required List<ExtraCharge> extraCharges,
  int addedPackagesTotal = 0,
  Discount? discount,
  int? flatPackagePrice, // jika paket durasi flat, biaya sewa = harga paket
}) {
  final rentalFee = flatPackagePrice ?? rentalCost(elapsed: elapsed, ratePerHour: ratePerHour, mode: mode);
  final extraTotal = extraCharges.fold<int>(0, (acc, c) => acc + c.subtotal);
  final disc = discountAmount(rentalFee + extraTotal + addedPackagesTotal, discount);
  return SessionBill(
    rentalFee: rentalFee,
    extraChargesTotal: extraTotal,
    addedPackagesTotal: addedPackagesTotal,
    discount: discount,
    discountAmount: disc,
    subtotal: (rentalFee + extraTotal + addedPackagesTotal) - disc,
  );
}

/// Hitung diskon + pajak + service charge untuk transaksi POS.
class TransactionTotals {
  final int subtotal;
  final int discountAmount;
  final int memberDiscountAmount; // diskon otomatis saat nama member diisi
  final int taxableBase; // subtotal - diskon - diskon member
  final int taxAmount;
  final int serviceChargeAmount;
  final int total;

  const TransactionTotals({
    required this.subtotal,
    required this.discountAmount,
    required this.memberDiscountAmount,
    required this.taxableBase,
    required this.taxAmount,
    required this.serviceChargeAmount,
    required this.total,
  });
}

TransactionTotals calculateTransactionTotals({
  required int subtotal,
  Discount? discount,
  double memberDiscountPercent = 0,
  required double taxPercent,
  required double serviceChargePercent,
}) {
  final disc = discountAmount(subtotal, discount);
  final base = subtotal - disc;
  final memberDisc = memberDiscountPercent > 0
      ? (base * memberDiscountPercent / 100).round().clamp(0, base)
      : 0;
  final afterMember = base - memberDisc;
  final serviceCharge = (afterMember * serviceChargePercent / 100).round();
  final tax = (afterMember * taxPercent / 100).round();
  return TransactionTotals(
    subtotal: subtotal,
    discountAmount: disc,
    memberDiscountAmount: memberDisc,
    taxableBase: afterMember,
    serviceChargeAmount: serviceCharge,
    taxAmount: tax,
    total: afterMember + tax + serviceCharge,
  );
}