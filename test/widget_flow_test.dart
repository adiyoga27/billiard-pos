import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:yesbilliard/features/auth/domain/app_user.dart';
import 'package:yesbilliard/features/auth/providers/auth_providers.dart';
import 'package:yesbilliard/features/pos/data/pos_repository.dart';
import 'package:yesbilliard/features/pos/domain/product_models.dart';
import 'package:yesbilliard/features/pos/presentation/checkout_screen.dart';
import 'package:yesbilliard/features/pos/providers/pos_providers.dart';
import 'package:yesbilliard/features/settings/data/settings_repository.dart';
import 'package:yesbilliard/features/tables/data/tables_repository.dart';
import 'package:yesbilliard/features/tables/domain/package_models.dart';
import 'package:yesbilliard/features/tables/domain/table_models.dart';
import 'package:yesbilliard/features/tables/presentation/add_package_screen.dart';
import 'package:yesbilliard/features/tables/presentation/table_detail_screen.dart';
import 'package:yesbilliard/features/tables/providers/tables_providers.dart';

/// Test WIDGET alur UI: tambah paket 2x lewat layar AddPackageScreen,
/// lalu checkout penuh dari CheckoutScreen — semuanya dengan FakeFirebaseFirestore.
void main() {
  final kasir = AppUser(
    uid: 'u1',
    nama: 'Budi',
    email: 'budi@yesbilliard.id',
    role: UserRole.kasir,
  );

  Future<void> seed(FakeFirebaseFirestore db) async {
    await db.collection('tables').doc('t1').set({
      'nama_meja': 'Meja 1',
      'tarif_per_jam': 30000,
      'status': 'kosong',
      'metode_pembulatan': 'per_15_menit',
    });
    await db.collection('packages').doc('pkg2jam').set({
      'nama_paket': 'Paket 2 Jam',
      'tipe': 'durasi_flat',
      'durasi_menit': 120,
      'harga': 50000,
      'hari_aktif': <int>[],
      'berlaku_untuk_meja': <String>[],
      'is_active': true,
    });
    await db.collection('categories').doc('c1').set({'nama': 'Makanan'});
    await db.collection('products').doc('p1').set({
      'nama': 'Nasi Goreng',
      'kategori_id': 'c1',
      'harga': 25000,
      'stok': 50,
    });
    await db.collection('settings').doc('global').set({
      'nama_toko': 'YES BILLIARD',
      'pembulatan': 'per_15_menit',
      'ambang_peringatan_menit': 10,
      'pajak_persen': 0.0,
      'service_charge_persen': 0.0,
    });
  }

  group('AddPackageScreen — tambah paket 2x (bug report)', () {
    testWidgets('tambah paket pertama OK, tambah lagi (layar dibuka ulang) tetap OK',
        (tester) async {
      final db = FakeFirebaseFirestore();
      await seed(db);
      final tablesRepo = TablesRepository(db: db);

      final t = BillTable.fromFirestore(
          't1', (await db.collection('tables').doc('t1').get()).data()!);
      final started = await tablesRepo.startSession(
        table: t,
        kasir: kasir,
        mode: SessionMode.durasiTetap,
        targetDurationMinutes: 60,
      );

      final navKey = GlobalKey<NavigatorState>();

      Future<void> pumpScreen() async {
        final router = GoRouter(
          navigatorKey: navKey,
          initialLocation: '/base',
          routes: [
            GoRoute(
              path: '/base',
              builder: (_, _) => const Scaffold(body: Center(child: Text('base'))),
            ),
            GoRoute(
              path: '/add-package',
              builder: (_, state) =>
                  AddPackageScreen(session: state.extra as TableSession),
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tablesRepositoryProvider.overrideWithValue(tablesRepo),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<TableSession> freshSession() async {
        final snap = await db.collection('table_sessions').doc(started.id).get();
        return TableSession.fromFirestore(started.id, snap.data()!);
      }

      // ===== Tambah paket KE-1 =====
      await pumpScreen();
      var s0 = await freshSession();
      navKey.currentContext!.push('/add-package', extra: s0);
      await tester.pumpAndSettle();

      expect(find.text('Tambah Paket ke Sesi'), findsOneWidget);
      expect(find.text('Paket 2 Jam'), findsOneWidget);

      await tester.tap(find.text('Tambah'));
      await tester.pumpAndSettle();

      // Berhasil → layar kembali ke base
      expect(find.text('base'), findsOneWidget);

      var s1 = await freshSession();
      expect(s1.paketTambahan.length, 1);
      expect(s1.paketTambahan.first.namaPaket, 'Paket 2 Jam');
      expect(s1.waktuSelesaiTarget!.difference(s1.waktuMulai).inMinutes, 180);

      // ===== Tambah paket KE-2 (layar dibuka ulang seperti alur nyata) =====
      var sAfter1 = await freshSession();
      navKey.currentContext!.push('/add-package', extra: sAfter1);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tambah'));
      await tester.pumpAndSettle();

      expect(find.text('base'), findsOneWidget);

      final s2 = await freshSession();
      expect(s2.paketTambahan.length, 2);
      expect(s2.paketTambahan.map((p) => p.namaPaket), ['Paket 2 Jam', 'Paket 2 Jam']);
      expect(s2.paketTambahanTotal, 100000);
      expect(s2.waktuSelesaiTarget!.difference(s2.waktuMulai).inMinutes, 300);
      expect(s2.riwayatPerpanjangan, [120, 120]);
    });
  });

  group('CheckoutScreen — checkout walk-in penuh', () {
    late FakeFirebaseFirestore db;
    late PosRepository posRepo;

    final nasiGoreng = const Product(
      id: 'p1',
      nama: 'Nasi Goreng',
      kategoriId: 'c1',
      harga: 25000,
      stok: 50,
    );

    setUp(() async {
      db = FakeFirebaseFirestore();
      await seed(db);
      posRepo = PosRepository(db: db);
    });

    Future<void> pumpCheckout(
      WidgetTester tester, {
      List<CartItem> items = const [],
      TableSession? session,
      List<Override> extraOverrides = const [],
    }) async {
      final router = GoRouter(
        initialLocation: '/checkout',
        routes: [
          GoRoute(
            path: '/checkout',
            builder: (_, _) => CheckoutScreen(
              items: items,
              sessionToFinalize: session,
              title: 'Checkout Walk-in',
            ),
          ),
          GoRoute(
            path: '/pos',
            builder: (_, _) => const Scaffold(body: Center(child: Text('POS'))),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            posRepositoryProvider.overrideWithValue(posRepo),
            settingsRepositoryProvider
                .overrideWithValue(SettingsRepository(db: db)),
            currentUserProvider.overrideWithValue(kasir),
            ...extraOverrides,
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('bayar tunai dengan diskon → struk muncul → transaksi tersimpan',
        (tester) async {
      await pumpCheckout(tester, items: [CartItem(nasiGoreng, 2)]);

      // Total awal 2 x 25.000 = 50.000
      expect(find.text('Rp 50.000'), findsWidgets);

      // Aktifkan diskon 10%
      await tester.tap(find.text('Pakai diskon'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Diskon (%)'), '10');
      await tester.pumpAndSettle();

      // Uang diterima 100.000 → kembalian 55.000
      await tester.enterText(find.widgetWithText(TextField, 'Uang tunai (Rp)'), '100000');
      await tester.pumpAndSettle();
      expect(find.textContaining('Kembalian: Rp 55.000'), findsOneWidget);

      await tester.tap(find.text('Bayar & Cetak Struk'));
      await tester.pumpAndSettle();

      expect(find.text('Transaksi Berhasil'), findsOneWidget);

      final snap = await db.collection('transactions').limit(1).get();
      expect(snap.docs, isNotEmpty);
      final tx = Transaction.fromFirestore(snap.docs.first.id, snap.docs.first.data());
      expect(tx.total, 45000);
      expect(tx.kembalian, 55000);
      expect(tx.items.single.qty, 2);

      final pSnap = await db.collection('products').doc('p1').get();
      expect(pSnap.data()!['stok'], 48);

      // Tutup struk → pindah ke POS
      await tester.tap(find.text('Transaksi Baru'));
      await tester.pumpAndSettle();
      expect(find.text('POS'), findsOneWidget);
    });

    testWidgets('uang tunai kurang dari total → error & transaksi TIDAK tersimpan',
        (tester) async {
      await pumpCheckout(tester, items: [CartItem(nasiGoreng, 2)]);

      await tester.enterText(find.widgetWithText(TextField, 'Uang tunai (Rp)'), '10000');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bayar & Cetak Struk'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Uang tunai kurang dari total'), findsOneWidget);
      final snap = await db.collection('transactions').limit(1).get();
      expect(snap.docs, isEmpty);
    });

    testWidgets('checkout gabungan sesi meja (setelah 2x tambah paket) berhasil',
        (tester) async {
      final tablesRepo = TablesRepository(db: db);
      final t = BillTable.fromFirestore(
          't1', (await db.collection('tables').doc('t1').get()).data()!);
      final s = await tablesRepo.startSession(
        table: t,
        kasir: kasir,
        mode: SessionMode.durasiTetap,
        targetDurationMinutes: 60,
      );
      final pkg = PlayPackage.fromFirestore(
          'pkg2jam', (await db.collection('packages').doc('pkg2jam').get()).data()!);
      await tablesRepo.addPackageToSession(sessionId: s.id, paket: pkg);
      await tablesRepo.addPackageToSession(sessionId: s.id, paket: pkg);

      final snap = await db.collection('table_sessions').doc(s.id).get();
      final freshSession = TableSession.fromFirestore(s.id, snap.data()!);
      expect(freshSession.paketTambahan.length, 2);

      await pumpCheckout(
        tester,
        items: [CartItem(nasiGoreng, 1)],
        session: freshSession,
        extraOverrides: [
          nowTickProvider.overrideWith((ref) => Stream.value(DateTime.now())),
          tablesRepositoryProvider.overrideWithValue(TablesRepository(db: db)),
        ],
      );

      // Ringkasan menampilkan paket tambahan 2x sebagai satu baris qty
      expect(find.text('Paket tambahan: Paket 2 Jam × 2'), findsOneWidget);
      // subtotal meja: sewa 1 blok 15m (7.500) + 2 paket (100.000) → muncul di
      // kartu sesi & ringkasan bawah
      expect(find.text('Rp 107.500'), findsNWidgets(2));

      // Bayar pakai QRIS (tanpa uang tunai)
      await tester.ensureVisible(find.text('QRIS'));
      await tester.tap(find.text('QRIS'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Bayar & Cetak Struk'));
      await tester.tap(find.text('Bayar & Cetak Struk'));
      await tester.pumpAndSettle();

      expect(find.text('Transaksi Berhasil'), findsOneWidget);

      final txSnap = await db.collection('transactions').limit(1).get();
      final tx = Transaction.fromFirestore(txSnap.docs.first.id, txSnap.docs.first.data());
      expect(tx.sessionFinalized, isTrue);
      expect(tx.tableName, 'Meja 1');

      final sDoneSnap = await db.collection('table_sessions').doc(s.id).get();
      final sDone = TableSession.fromFirestore(s.id, sDoneSnap.data()!);
      expect(sDone.status, SessionStatus.selesai);
      // sewa blok 15 menit (7500) + 2 paket (100000) = 107500
      expect(sDone.biaya, 107500);

      final tNowSnap = await db.collection('tables').doc('t1').get();
      expect(tNowSnap.data()!['status'], 'kosong');
    });
  });

  group('TableDetailScreen — batalkan sesi (tanpa tagihan)', () {
    testWidgets('tombol Batalkan Sesi → konfirmasi → sesi batal & meja kosong',
        (tester) async {
      final db = FakeFirebaseFirestore();
      await seed(db);
      final tablesRepo = TablesRepository(db: db);

      final t = BillTable.fromFirestore(
          't1', (await db.collection('tables').doc('t1').get()).data()!);
      final s = await tablesRepo.startSession(
        table: t,
        kasir: kasir,
        mode: SessionMode.durasiTetap,
        targetDurationMinutes: 60,
      );

      const product = Product(
          id: 'p1', nama: 'Nasi Goreng', kategoriId: 'c1', harga: 25000, stok: 50);

      final container = ProviderContainer(
        overrides: [
          tablesRepositoryProvider.overrideWithValue(tablesRepo),
          settingsRepositoryProvider.overrideWithValue(SettingsRepository(db: db)),
          currentUserProvider.overrideWithValue(kasir),
          nowTickProvider.overrideWith((ref) => Stream.value(DateTime.now())),
        ],
      );
      addTearDown(container.dispose);
      container.read(tableCartControllerProvider.notifier).addProduct('t1', product);

      final router = GoRouter(
        initialLocation: '/table/t1',
        routes: [
          GoRoute(
            path: '/table/:tableId',
            builder: (_, state) =>
                TableDetailScreen(tableId: state.pathParameters['tableId']!),
          ),
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('dash')),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Sesi aktif: tombol batal tersedia + pesanan meja terlihat
      expect(find.text('Batalkan Sesi'), findsOneWidget);
      expect(find.text('Nasi Goreng'), findsOneWidget);

      await tester.tap(find.text('Batalkan Sesi'));
      await tester.pumpAndSettle();
      expect(find.text('Batalkan Sesi?'), findsOneWidget);

      await tester.tap(find.text('Ya, Batalkan'));
      await tester.pumpAndSettle();

      // Sesi batal: tombol hilang, meja kembali kosong
      expect(find.text('Batalkan Sesi'), findsNothing);
      expect(find.text('Meja kosong'), findsOneWidget);

      // Pesanan meja ikut dibersihkan
      expect(container.read(tableCartControllerProvider)['t1'] ?? const <CartItem>[], isEmpty);

      // Data Firestore: status batal, biaya 0, meja kosong
      final sSnap = await db.collection('table_sessions').doc(s.id).get();
      expect(sSnap.data()!['status'], 'batal');
      expect(sSnap.data()!['biaya'], 0);
      final tSnap = await db.collection('tables').doc('t1').get();
      expect(tSnap.data()!['status'], 'kosong');
      expect(tSnap.data()!.containsKey('current_session_id'), isFalse);

      // Riwayat menampilkan label Dibatalkan
      expect(find.text('Dibatalkan'), findsOneWidget);
    });
  });
}
