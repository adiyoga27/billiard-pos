import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yesbilliard/features/pos/domain/product_models.dart';
import 'package:yesbilliard/features/reports/data/reports_repository.dart';
import 'package:yesbilliard/features/tables/domain/table_models.dart';

void main() {
  Transaction tx({
    required String id,
    required int total,
    required DateTime at,
    List<TransactionItem> items = const [],
    bool sessionFinalized = false,
    String kasirId = 'u1',
  }) =>
      Transaction(
        id: id,
        nomor: id,
        kasirId: kasirId,
        subtotal: total,
        diskon: 0,
        pajak: 0,
        serviceCharge: 0,
        total: total,
        metodeBayar: PaymentMethod.tunai,
        createdAt: at,
        items: items,
        sessionFinalized: sessionFinalized,
      );

  group('Agregasi laporan (pure functions)', () {
    final repo = ReportsRepository(db: FakeFirebaseFirestore());

    test('revenuePerDay mengelompokkan total per hari', () {
      final list = [
        tx(id: 'a', total: 10000, at: DateTime(2026, 9, 1, 10)),
        tx(id: 'b', total: 20000, at: DateTime(2026, 9, 1, 14)),
        tx(id: 'c', total: 5000, at: DateTime(2026, 9, 2, 9)),
      ];
      final map = repo.revenuePerDay(list);
      expect(map[DateTime(2026, 9, 1)], 30000);
      expect(map[DateTime(2026, 9, 2)], 5000);
    });

    test('topProducts mengurutkan qty terlaris', () {
      final list = [
        tx(id: 'a', total: 1, at: DateTime(2026, 9, 1), items: [
          TransactionItem(productId: 'p1', nama: 'Nasi Goreng', qty: 2, hargaSatuan: 25000),
          TransactionItem(productId: 'p2', nama: 'Es Teh', qty: 5, hargaSatuan: 8000),
        ]),
        tx(id: 'b', total: 1, at: DateTime(2026, 9, 2), items: [
          TransactionItem(productId: 'p1', nama: 'Nasi Goreng', qty: 1, hargaSatuan: 25000),
        ]),
      ];
      final top = repo.topProducts(list);
      expect(top.first.nama, 'Es Teh');
      expect(top.first.qty, 5);
      expect(top[1].nama, 'Nasi Goreng');
      expect(top[1].qty, 3);
    });

    test('revenuePerTable memakai biaya sesi selesai', () {
      TableSession s(String id, String? nama, int biaya) => TableSession(
            id: id,
            tableId: 't',
            tableName: nama,
            waktuMulai: DateTime(2026, 9, 1, 10),
            kasirId: 'u1',
            status: SessionStatus.selesai,
            mode: SessionMode.bebas,
            biaya: biaya,
          );
      final map = repo.revenuePerTable([
        s('s1', 'Meja 1', 40000),
        s('s2', 'Meja 1', 20000),
        s('s3', 'Meja 2', 90000),
      ]);
      expect(map['Meja 1'], 60000);
      expect(map['Meja 2'], 90000);
    });

    test('counterRevenue vs tableRevenue', () {
      final list = [
        tx(id: 'a', total: 30000, at: DateTime(2026, 9, 1), sessionFinalized: false),
        tx(id: 'b', total: 70000, at: DateTime(2026, 9, 1), sessionFinalized: true),
      ];
      expect(repo.counterRevenue(list), 30000);
      expect(repo.tableRevenue(list), 70000);
    });
  });

  group('Query laporan dari Firestore', () {
    test('transactionsInRange memfilter rentang & kasir', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('transactions').doc('t1').set({
        'nomor': 'INV-1',
        'kasir_id': 'u1',
        'subtotal': 10000,
        'diskon': 0,
        'pajak': 0,
        'service_charge': 0,
        'total': 10000,
        'metode_bayar': 'tunai',
        'created_at': Timestamp.fromDate(DateTime(2026, 9, 1, 12)),
        'items': <Map<String, dynamic>>[],
        'session_finalized': false,
      });
      await db.collection('transactions').doc('t2').set({
        'nomor': 'INV-2',
        'kasir_id': 'u2',
        'subtotal': 20000,
        'diskon': 0,
        'pajak': 0,
        'service_charge': 0,
        'total': 20000,
        'metode_bayar': 'qris',
        'created_at': Timestamp.fromDate(DateTime(2026, 9, 5, 12)),
        'items': <Map<String, dynamic>>[],
        'session_finalized': false,
      });

      final repo = ReportsRepository(db: db);
      final inRange = await repo.transactionsInRange(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      );
      expect(inRange.length, 2);

      final byKasir = await repo.transactionsInRange(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        kasirId: 'u1',
      );
      expect(byKasir.length, 1);
      expect(byKasir.single.kasirId, 'u1');
    });

    test('sessionsFinishedInRange memfilter sesi selesai dalam rentang', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('table_sessions').doc('s1').set({
        'table_id': 't1',
        'waktu_mulai': Timestamp.fromDate(DateTime(2026, 9, 1, 10)),
        'waktu_selesai': Timestamp.fromDate(DateTime(2026, 9, 1, 12)),
        'durasi_menit': 120,
        'biaya': 50000,
        'kasir_id': 'u1',
        'status': 'selesai',
        'mode': 'bebas',
      });
      await db.collection('table_sessions').doc('s2').set({
        'table_id': 't2',
        'waktu_mulai': Timestamp.fromDate(DateTime(2026, 9, 3, 10)),
        'waktu_selesai': Timestamp.fromDate(DateTime(2026, 9, 3, 11)),
        'durasi_menit': 60,
        'biaya': 30000,
        'kasir_id': 'u1',
        'status': 'selesai',
        'mode': 'bebas',
      });
      await db.collection('table_sessions').doc('s3').set({
        'table_id': 't3',
        'waktu_mulai': Timestamp.fromDate(DateTime(2026, 9, 10, 10)),
        'kasir_id': 'u1',
        'status': 'berjalan',
        'mode': 'bebas',
        'biaya': 0,
      });

      final repo = ReportsRepository(db: db);
      final done = await repo.sessionsFinishedInRange(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 2),
      );
      expect(done.length, 1);
      expect(done.single.id, 's1');
    });
  });
}
