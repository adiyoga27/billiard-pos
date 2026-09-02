import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:yesbilliard/features/auth/domain/app_user.dart';
import 'package:yesbilliard/features/auth/providers/auth_providers.dart';
import 'package:yesbilliard/features/pos/data/pos_repository.dart';
import 'package:yesbilliard/features/pos/domain/product_models.dart';
import 'package:yesbilliard/features/pos/presentation/pos_screen.dart';
import 'package:yesbilliard/features/pos/providers/pos_providers.dart';

/// Regression: layar Kasir Walk-in tidak boleh overflow (bottom overflowed)
/// di berbagai ukuran layar, termasuk saat keranjang berisi.
void main() {
  final kasir = AppUser(
      uid: 'u1', nama: 'Budi', email: 'budi@x.id', role: UserRole.kasir);

  Future<FakeFirebaseFirestore> seedDb() async {
    final db = FakeFirebaseFirestore();
    await db.collection('categories').doc('c1').set({'nama': 'Makanan'});
    await db.collection('products').doc('p1').set({
      'nama': 'Nasi Goreng Spesial Komplit',
      'kategori_id': 'c1',
      'harga': 25000,
      'stok': 50,
    });
    await db.collection('products').doc('p2').set({
      'nama': 'Es Teh Manis',
      'kategori_id': 'c1',
      'harga': 8000,
      'stok': 80,
    });
    return db;
  }

  for (final (width, height) in [(800.0, 600.0), (390.0, 844.0), (360.0, 640.0), (844.0, 390.0)]) {
    testWidgets('tidak overflow di ${width.toInt()}x${height.toInt()} (keranjang berisi)',
        (tester) async {
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final db = await seedDb();
      final container = ProviderContainer(
        overrides: [
          posRepositoryProvider.overrideWithValue(PosRepository(db: db)),
          currentUserProvider.overrideWithValue(kasir),
        ],
      );
      addTearDown(container.dispose);

      final router = GoRouter(
        initialLocation: '/pos',
        routes: [
          GoRoute(path: '/pos', builder: (_, _) => const PosScreen()),
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('dash'))),
          GoRoute(path: '/checkout', builder: (_, _) => const Scaffold(body: Text('co'))),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      container.read(cartControllerProvider.notifier).addProduct(const Product(
          id: 'p1', nama: 'Nasi Goreng Spesial Komplit', kategoriId: 'c1', harga: 25000, stok: 50));
      container.read(cartControllerProvider.notifier).addProduct(const Product(
          id: 'p2', nama: 'Es Teh Manis', kategoriId: 'c1', harga: 8000, stok: 80));
      await tester.pumpAndSettle();

      // Layar < 1000px menampilkan tombol "Keranjang" → buka bottom sheet.
      if (width < 1000) {
        await tester.tap(find.text('Keranjang').first);
        await tester.pumpAndSettle();
      }
      // Tanpa exception overflow, test dinyatakan lulus.
      expect(tester.takeException(), isNull);
    });
  }
}
