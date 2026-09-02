import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:yesbilliard/features/auth/domain/app_user.dart';
import 'package:yesbilliard/features/auth/providers/auth_providers.dart';
import 'package:yesbilliard/features/reports/data/reports_repository.dart';
import 'package:yesbilliard/features/reports/presentation/reports_screen.dart';
import 'package:yesbilliard/features/reports/providers/reports_providers.dart';

/// Regression: laporan harus BISA dibuka — sebelumnya layar loading terus
/// karena ReportFilter tidak punya value equality (provider family dibuat
/// ulang setiap rebuild).
void main() {
  final kasirBudi = const AppUser(
      uid: 'u1', nama: 'Budi', email: 'budi@x.id', role: UserRole.kasir);
  final kasirSari = const AppUser(
      uid: 'u2', nama: 'Sari', email: 'sari@x.id', role: UserRole.kasir);

  Future<FakeFirebaseFirestore> seedDb() async {
    final db = FakeFirebaseFirestore();
    Future<void> tx(String id, String kasirId, String kasirNama, DateTime at,
        int total) async {
      await db.collection('transactions').doc(id).set({
        'nomor': 'INV-$id',
        'kasir_id': kasirId,
        'kasir_nama': kasirNama,
        'subtotal': total,
        'diskon': 0,
        'diskon_member': 0,
        'pajak': 0,
        'service_charge': 0,
        'total': total,
        'metode_bayar': 'tunai',
        'created_at': Timestamp.fromDate(at),
        'items': <Map<String, dynamic>>[],
        'session_finalized': false,
      });
    }

    await tx('t1', 'u1', 'Budi', DateTime.now(), 25000);
    await tx('t2', 'u2', 'Sari', DateTime.now(), 40000);
    await db.collection('table_sessions').doc('s1').set({
      'table_id': 't1',
      'table_name': 'Meja 1',
      'waktu_mulai': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 1))),
      'waktu_selesai': Timestamp.fromDate(DateTime.now()),
      'durasi_menit': 60,
      'biaya': 30000,
      'kasir_id': 'u1',
      'status': 'selesai',
      'mode': 'bebas',
    });
    return db;
  }

  testWidgets('laporan terbuka: data tampil, filter kasir berfungsi, tidak loop',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final db = await seedDb();
    final container = ProviderContainer(
      overrides: [
        reportsRepositoryProvider.overrideWithValue(ReportsRepository(db: db)),
        staffStreamProvider.overrideWith((ref) => Stream.value([kasirBudi, kasirSari])),
        currentUserProvider.overrideWithValue(kasirBudi),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/reports',
      routes: [
        GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen()),
        GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('dash'))),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    // pumpAndSettle HARUS selesai (regression: dulu loop tanpa henti).
    await tester.pumpAndSettle();

    expect(find.text('Laporan Penjualan'), findsOneWidget);
    // Total pendapatan = 25.000 + 40.000 + sesi 30.000? — pendapatan total
    // dihitung dari transaksi saja di layar ringkasan; sesi masuk ke
    // "Sesi Meja" bila tergabung. Cek riwayat transaksi tampil:
    expect(find.textContaining('INV-t1'), findsOneWidget);
    expect(find.textContaining('INV-t2'), findsOneWidget);

    // Filter kasir: pilih "Budi" → hanya transaksi Budi
    await tester.tap(find.text('Semua kasir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Budi').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('INV-t1'), findsOneWidget);
    expect(find.textContaining('INV-t2'), findsNothing);
  });
}
