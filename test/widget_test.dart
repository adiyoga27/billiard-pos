import 'package:flutter_test/flutter_test.dart';
import 'package:yesbilliard/core/domain/billing_calculator.dart';

void main() {
  group('billedMinutes — pembulatan waktu sewa', () {
    test('per menit: minimal 1 menit', () {
      expect(billedMinutes(const Duration(seconds: 30), RoundingMode.perMinute), 1);
      expect(billedMinutes(const Duration(minutes: 5), RoundingMode.perMinute), 5);
      expect(billedMinutes(const Duration(minutes: 5, seconds: 59), RoundingMode.perMinute), 5);
    });

    test('per 15 menit: selalu kelipatan 15, minimal 15', () {
      expect(billedMinutes(const Duration(minutes: 1), RoundingMode.per15Minutes), 15);
      expect(billedMinutes(const Duration(minutes: 14), RoundingMode.per15Minutes), 15);
      expect(billedMinutes(const Duration(minutes: 15), RoundingMode.per15Minutes), 15);
      expect(billedMinutes(const Duration(minutes: 16), RoundingMode.per15Minutes), 30);
      expect(billedMinutes(const Duration(minutes: 47), RoundingMode.per15Minutes), 60);
    });

    test('per jam penuh: selalu kelipatan 60, minimal 60', () {
      expect(billedMinutes(const Duration(minutes: 1), RoundingMode.perHour), 60);
      expect(billedMinutes(const Duration(minutes: 61), RoundingMode.perHour), 120);
    });
  });

  group('rentalCost — biaya sewa berjalan', () {
    test('tarif 30.000/jam, 30 menit, per menit = 15.000', () {
      final cost = rentalCost(
        elapsed: const Duration(minutes: 30),
        ratePerHour: 30000,
        mode: RoundingMode.perMinute,
      );
      expect(cost, 15000);
    });

    test('tarif 30.000/jam, per 15 menit: 1 menit tetap 7.500', () {
      final cost = rentalCost(
        elapsed: const Duration(minutes: 1),
        ratePerHour: 30000,
        mode: RoundingMode.per15Minutes,
      );
      expect(cost, 7500);
    });

    test('tarif 30.000/jam, 46 menit, per 15 menit = 4 blok x 7.500 = 30.000', () {
      final cost = rentalCost(
        elapsed: const Duration(minutes: 46),
        ratePerHour: 30000,
        mode: RoundingMode.per15Minutes,
      );
      expect(cost, 30000);
    });

    test('tarif 50.000/jam, per jam penuh: 90 menit = 100.000', () {
      final cost = rentalCost(
        elapsed: const Duration(minutes: 90),
        ratePerHour: 50000,
        mode: RoundingMode.perHour,
      );
      expect(cost, 100000);
    });
  });

  group('discountAmount', () {
    test('persen tidak boleh melebihi subtotal', () {
      expect(discountAmount(10000, const Discount(type: DiscountType.percent, value: 150)), 10000);
      expect(discountAmount(10000, const Discount(type: DiscountType.percent, value: 10)), 1000);
    });

    test('nominal dibatasi subtotal', () {
      expect(discountAmount(5000, const Discount(type: DiscountType.nominal, value: 99999)), 5000);
      expect(discountAmount(5000, const Discount(type: DiscountType.nominal, value: 2000)), 2000);
    });
  });

  group('calculateSessionBill — breakdown tagihan sesi', () {
    test('bebas + biaya tambahan + diskon', () {
      final bill = calculateSessionBill(
        elapsed: const Duration(hours: 1),
        ratePerHour: 30000,
        mode: RoundingMode.perMinute,
        extraCharges: [
          ExtraCharge(
            nama: 'Sewa stik premium',
            jumlah: 1,
            hargaSatuan: 10000,
            ditambahkanOleh: 'u1',
            waktuDitambahkan: DateTime(2026, 1, 1),
          ),
        ],
        discount: const Discount(type: DiscountType.percent, value: 10, reason: 'member'),
      );
      // sewa 30.000 + tambahan 10.000 = 40.000 - 10% (4.000) = 36.000
      expect(bill.rentalFee, 30000);
      expect(bill.extraChargesTotal, 10000);
      expect(bill.discountAmount, 4000);
      expect(bill.subtotal, 36000);
    });

    test('paket durasi flat: biaya sewa = harga paket, bukan hitung per menit', () {
      final bill = calculateSessionBill(
        elapsed: const Duration(hours: 3),
        ratePerHour: 30000,
        mode: RoundingMode.perMinute,
        extraCharges: const [],
        flatPackagePrice: 50000,
      );
      expect(bill.rentalFee, 50000);
      expect(bill.subtotal, 50000);
    });

    test('paket ditambah di tengah sesi ikut dihitung + diskon berlaku atas total', () {
      // Sesi tarif normal 30rb/jam jalan 1 jam, lalu beli paket tambahan 50rb.
      final bill = calculateSessionBill(
        elapsed: const Duration(hours: 1),
        ratePerHour: 30000,
        mode: RoundingMode.perMinute,
        extraCharges: const [],
        addedPackagesTotal: 50000,
        discount: const Discount(type: DiscountType.percent, value: 10),
      );
      expect(bill.rentalFee, 30000);
      expect(bill.addedPackagesTotal, 50000);
      // (30.000 + 50.000) - 10% = 72.000
      expect(bill.discountAmount, 8000);
      expect(bill.subtotal, 72000);
    });

    test('paket flat + paket tambahan di tengah sesi', () {
      final bill = calculateSessionBill(
        elapsed: const Duration(hours: 5),
        ratePerHour: 30000,
        mode: RoundingMode.perMinute,
        extraCharges: const [],
        addedPackagesTotal: 50000,
        flatPackagePrice: 50000,
      );
      expect(bill.rentalFee, 50000);
      expect(bill.addedPackagesTotal, 50000);
      expect(bill.subtotal, 100000);
    });
  });

  group('calculateTransactionTotals — pajak & service charge', () {
    test('diskon + pajak 11% + service 5%', () {
      final t = calculateTransactionTotals(
        subtotal: 100000,
        discount: const Discount(type: DiscountType.percent, value: 10),
        taxPercent: 11,
        serviceChargePercent: 5,
      );
      expect(t.discountAmount, 10000);
      expect(t.taxableBase, 90000);
      expect(t.serviceChargeAmount, 4500);
      expect(t.taxAmount, 9900);
      expect(t.total, 104400);
    });

    test('tanpa pajak/service charge', () {
      final t = calculateTransactionTotals(
        subtotal: 50000,
        discount: null,
        taxPercent: 0,
        serviceChargePercent: 0,
      );
      expect(t.total, 50000);
    });
  });
}