import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yesbilliard/core/domain/billing_calculator.dart';
import 'package:yesbilliard/features/pos/data/pos_repository.dart';
import 'package:yesbilliard/features/tables/data/tables_repository.dart';
import 'package:yesbilliard/features/tables/domain/package_models.dart';
import 'package:yesbilliard/features/tables/domain/table_models.dart';

/// Test fitur manajemen (settings): meja, paket, produk, kategori.
void main() {
  late FakeFirebaseFirestore db;
  late TablesRepository tablesRepo;
  late PosRepository posRepo;

  setUp(() {
    db = FakeFirebaseFirestore();
    tablesRepo = TablesRepository(db: db);
    posRepo = PosRepository(db: db);
  });

  group('Manajemen meja', () {
    test('saveTable baru + edit + hapus', () async {
      await tablesRepo.saveTable(
          namaMeja: 'Meja 1', tarifPerJam: 30000, pembulatan: RoundingMode.per15Minutes);
      var snap = (await db.collection('tables').get()).docs.single;
      expect(snap.data()['nama_meja'], 'Meja 1');
      expect(snap.data()['status'], 'kosong');

      final id = snap.id;
      await tablesRepo.saveTable(
        id: id,
        namaMeja: 'Meja 1 VIP',
        tarifPerJam: 50000,
        pembulatan: RoundingMode.perHour,
      );
      final editedSnap = await db.collection('tables').doc(id).get();
      expect(editedSnap.data()!['nama_meja'], 'Meja 1 VIP');
      expect(editedSnap.data()!['tarif_per_jam'], 50000);
      expect(editedSnap.data()!['metode_pembulatan'], 'per_jam');

      await tablesRepo.deleteTable(id);
      expect((await db.collection('tables').get()).docs, isEmpty);
    });

    test('reserve meja & batalkan reserve', () async {
      await db.collection('tables').doc('t1').set({
        'nama_meja': 'Meja 1',
        'tarif_per_jam': 30000,
        'status': 'kosong',
        'metode_pembulatan': 'per_menit',
      });
      final t = BillTable.fromFirestore(
          't1', (await db.collection('tables').doc('t1').get()).data()!);
      await tablesRepo.setTableReserved(t, true);
      expect((await db.collection('tables').doc('t1').get()).data()!['status'], 'reserved');
      await tablesRepo.setTableReserved(t, false);
      expect((await db.collection('tables').doc('t1').get()).data()!['status'], 'kosong');
    });
  });

  group('Manajemen paket', () {
    test('savePackage baru + edit + hapus', () async {
      const pkg = PlayPackage(
        id: '',
        namaPaket: 'Paket 2 Jam',
        tipe: PackageType.durasiFlat,
        durasiMenit: 120,
        harga: 50000,
      );
      await tablesRepo.savePackage(pkg);
      final snap = (await db.collection('packages').get()).docs.single;
      expect(snap.data()['tipe'], 'durasi_flat');

      final saved = PlayPackage.fromFirestore(snap.id, snap.data());
      final edited = PlayPackage(
        id: saved.id,
        namaPaket: 'Paket 3 Jam',
        tipe: PackageType.durasiFlat,
        durasiMenit: 180,
        harga: 70000,
        hariAktif: const [1, 2, 3],
        jamMulaiBerlaku: 10,
        jamSelesaiBerlaku: 22,
        isActive: true,
      );
      await tablesRepo.savePackage(edited);

      final editedSnap = await db.collection('packages').doc(saved.id).get();
      final reloaded = PlayPackage.fromFirestore(
          saved.id, editedSnap.data()!);
      expect(reloaded.namaPaket, 'Paket 3 Jam');
      expect(reloaded.durasiMenit, 180);
      expect(reloaded.hariAktif, [1, 2, 3]);
      expect(reloaded.appliesAt(DateTime(2026, 9, 7, 15), 't1'), isTrue); // Senin 15:00
      expect(reloaded.appliesAt(DateTime(2026, 9, 8, 8), 't1'), isFalse); // di luar jam
      expect(reloaded.appliesAt(DateTime(2026, 9, 11, 15), 't1'), isFalse); // Jumat (hari 5)

      await tablesRepo.deletePackage(saved.id);
      expect((await db.collection('packages').get()).docs, isEmpty);
    });

    test('paket berlaku untuk meja tertentu', () async {
      const pkg = PlayPackage(
        id: '',
        namaPaket: 'Paket VIP',
        tipe: PackageType.tarifKhusus,
        harga: 25000,
        berlakuUntukMeja: ['t1', 't2'],
      );
      await tablesRepo.savePackage(pkg);
      final id = (await db.collection('packages').get()).docs.single.id;
      final snap = await db.collection('packages').doc(id).get();
      final reloaded = PlayPackage.fromFirestore(id, snap.data()!);
      expect(reloaded.appliesAt(DateTime(2026, 9, 7, 12), 't1'), isTrue);
      expect(reloaded.appliesAt(DateTime(2026, 9, 7, 12), 't9'), isFalse);
    });
  });

  group('Manajemen produk & kategori', () {
    test('saveProduct baru + edit + hapus', () async {
      await posRepo.saveProduct(
          nama: 'Nasi Goreng', kategoriId: 'c1', harga: 25000, stok: 50);
      final snap = (await db.collection('products').get()).docs.single;
      expect(snap.data()['stok'], 50);

      await posRepo.saveProduct(
        id: snap.id,
        nama: 'Nasi Goreng Spesial',
        kategoriId: 'c1',
        harga: 30000,
        stok: 40,
      );
      final reloaded = (await db.collection('products').doc(snap.id).get()).data()!;
      expect(reloaded['nama'], 'Nasi Goreng Spesial');
      expect(reloaded['harga'], 30000);

      await posRepo.deleteProduct(snap.id);
      expect((await db.collection('products').get()).docs, isEmpty);
    });

    test('deleteCategory ikut menghapus produknya', () async {
      await db.collection('categories').doc('c1').set({'nama': 'Makanan'});
      await db.collection('products').doc('p1').set({
        'nama': 'Nasi Goreng',
        'kategori_id': 'c1',
        'harga': 25000,
        'stok': 50,
      });
      await posRepo.deleteCategory('c1');
      expect((await db.collection('categories').get()).docs, isEmpty);
      expect((await db.collection('products').get()).docs, isEmpty);
    });
  });

  group('Riwayat meja', () {
    test('historyForTable mengembalikan sesi terbaru dulu', () async {
      Future<void> seedSession(String id, String tableId, DateTime mulai, int biaya) {
        return db.collection('table_sessions').doc(id).set({
          'table_id': tableId,
          'waktu_mulai': mulai,
          'waktu_selesai': mulai.add(const Duration(hours: 1)),
          'durasi_menit': 60,
          'biaya': biaya,
          'kasir_id': 'u1',
          'status': 'selesai',
          'mode': 'bebas',
        });
      }

      await seedSession('s1', 't1', DateTime(2026, 9, 1, 10), 30000);
      await seedSession('s2', 't1', DateTime(2026, 9, 2, 10), 35000);
      await seedSession('s3', 't2', DateTime(2026, 9, 2, 11), 40000);

      final history = await tablesRepo.historyForTable('t1');
      expect(history.length, 2);
      expect(history.first.id, 's2');
      expect(history.last.id, 's1');
    });
  });
}
