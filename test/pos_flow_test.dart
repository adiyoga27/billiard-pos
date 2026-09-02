import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yesbilliard/core/domain/billing_calculator.dart';
import 'package:yesbilliard/features/auth/domain/app_user.dart';
import 'package:yesbilliard/features/pos/data/pos_repository.dart';
import 'package:yesbilliard/features/pos/domain/product_models.dart';
import 'package:yesbilliard/features/settings/domain/settings_models.dart';
import 'package:yesbilliard/features/tables/data/tables_repository.dart';
import 'package:yesbilliard/features/tables/domain/package_models.dart';
import 'package:yesbilliard/features/tables/domain/table_models.dart';

/// Tes END-TO-END alur bisnis lengkap memakai FakeFirebaseFirestore:
/// mulai sesi → tambah paket (2x!) → perpanjang → biaya tambahan → diskon →
/// pesanan meja → checkout gabungan → verifikasi data final di Firestore.
void main() {
  late FakeFirebaseFirestore db;
  late TablesRepository tablesRepo;
  late PosRepository posRepo;

  final kasir = AppUser(
    uid: 'u1',
    nama: 'Budi',
    email: 'budi@yesbilliard.id',
    role: UserRole.kasir,
  );

  Future<BillTable> table(String id) async {
    final snap = await db.collection('tables').doc(id).get();
    return BillTable.fromFirestore(id, snap.data()!);
  }

  Future<TableSession?> session(String id) async {
    final snap = await db.collection('table_sessions').doc(id).get();
    if (!snap.exists) return null;
    return TableSession.fromFirestore(id, snap.data()!);
  }

  Future<void> seed() async {
    await db.collection('tables').doc('t1').set({
      'nama_meja': 'Meja 1',
      'tarif_per_jam': 30000,
      'status': 'kosong',
      'metode_pembulatan': 'per_15_menit',
    });
    await db.collection('tables').doc('t2').set({
      'nama_meja': 'Meja 2',
      'tarif_per_jam': 50000,
      'status': 'kosong',
      'metode_pembulatan': 'per_menit',
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
    await db.collection('packages').doc('pkg3jam').set({
      'nama_paket': 'Paket 3 Jam',
      'tipe': 'durasi_flat',
      'durasi_menit': 180,
      'harga': 70000,
      'hari_aktif': <int>[],
      'berlaku_untuk_meja': <String>[],
      'is_active': true,
    });
    await db.collection('packages').doc('pkgvip').set({
      'nama_paket': 'Paket VIP',
      'tipe': 'tarif_khusus',
      'harga': 25000,
      'hari_aktif': <int>[],
      'berlaku_untuk_meja': <String>[],
      'is_active': true,
    });
    await db.collection('categories').doc('c1').set({'nama': 'Makanan'});
    await db.collection('categories').doc('c2').set({'nama': 'Minuman'});
    await db.collection('products').doc('p1').set({
      'nama': 'Nasi Goreng',
      'kategori_id': 'c1',
      'harga': 25000,
      'stok': 50,
    });
    await db.collection('products').doc('p2').set({
      'nama': 'Es Teh',
      'kategori_id': 'c2',
      'harga': 8000,
      'stok': 80,
    });
    await db.collection('settings').doc('global').set({
      'nama_toko': 'YES BILLIARD',
      'pembulatan': 'per_15_menit',
      'ambang_peringatan_menit': 10,
      'pajak_persen': 0.0,
      'service_charge_persen': 0.0,
    });
  }

  setUp(() {
    db = FakeFirebaseFirestore();
    tablesRepo = TablesRepository(db: db);
    posRepo = PosRepository(db: db);
  });

  group('Mulai sesi (semua mode)', () {
    test('bebas: meja jadi terpakai, sesi berjalan tanpa target', () async {
      await seed();
      final t = await table('t1');
      final s = await tablesRepo.startSession(table: t, kasir: kasir, mode: SessionMode.bebas);
      expect(s.status, SessionStatus.berjalan);
      expect(s.mode, SessionMode.bebas);
      expect(s.waktuSelesaiTarget, isNull);
      final tNow = await table('t1');
      expect(tNow.status, TableStatus.terpakai);
      expect(tNow.currentSessionId, s.id);
    });

    test('durasi tetap: target selesai = mulai + durasi', () async {
      await seed();
      final t = await table('t1');
      final s = await tablesRepo.startSession(
        table: t,
        kasir: kasir,
        mode: SessionMode.durasiTetap,
        targetDurationMinutes: 90,
      );
      expect(s.mode, SessionMode.durasiTetap);
      final target = s.waktuSelesaiTarget!;
      expect(target.difference(s.waktuMulai).inMinutes, 90);
    });

    test('paket durasi flat: mode jadi durasiTetap + target sesuai paket', () async {
      await seed();
      final t = await table('t1');
      final pkg = PlayPackage.fromFirestore(
          'pkg2jam', (await db.collection('packages').doc('pkg2jam').get()).data()!);
      final s = await tablesRepo.startSession(
        table: t,
        kasir: kasir,
        mode: SessionMode.bebas,
        paket: pkg,
        paketNama: pkg.namaPaket,
      );
      expect(s.mode, SessionMode.durasiTetap);
      expect(s.packageId, 'pkg2jam');
      expect(s.waktuSelesaiTarget!.difference(s.waktuMulai).inMinutes, 120);
    });

    test('meja yang sudah terpakai tidak bisa mulai sesi lagi', () async {
      await seed();
      final t = await table('t1');
      await tablesRepo.startSession(table: t, kasir: kasir, mode: SessionMode.bebas);
      final tBusy = await table('t1');
      expect(
        () => tablesRepo.startSession(table: tBusy, kasir: kasir, mode: SessionMode.bebas),
        throwsStateError,
      );
    });
  });

  group('Tambah paket di tengah sesi (bug: 2x tambah paket)', () {
    test('1x tambah paket flat: durasi + biaya tercatat', () async {
      await seed();
      final t = await table('t1');
      final s = await tablesRepo.startSession(
        table: t,
        kasir: kasir,
        mode: SessionMode.durasiTetap,
        targetDurationMinutes: 60,
      );
      final pkg = PlayPackage.fromFirestore(
          'pkg2jam', (await db.collection('packages').doc('pkg2jam').get()).data()!);

      await tablesRepo.addPackageToSession(sessionId: s.id, paket: pkg);

      final s2 = (await session(s.id))!;
      expect(s2.paketTambahan.length, 1);
      expect(s2.paketTambahan.first.namaPaket, 'Paket 2 Jam');
      expect(s2.paketTambahan.first.harga, 50000);
      expect(s2.paketTambahanTotal, 50000);
      // target awal +60m lalu +120m = +180m dari mulai
      expect(s2.waktuSelesaiTarget!.difference(s2.waktuMulai).inMinutes, 180);
      expect(s2.riwayatPerpanjangan, [120]);
    });

    test('2x tambah paket flat: dua entri + durasi bertambah dua kali', () async {
      await seed();
      final t = await table('t1');
      final s = await tablesRepo.startSession(
        table: t,
        kasir: kasir,
        mode: SessionMode.durasiTetap,
        targetDurationMinutes: 60,
      );
      final pkg2 = PlayPackage.fromFirestore(
          'pkg2jam', (await db.collection('packages').doc('pkg2jam').get()).data()!);
      final pkg3 = PlayPackage.fromFirestore(
          'pkg3jam', (await db.collection('packages').doc('pkg3jam').get()).data()!);

      await tablesRepo.addPackageToSession(sessionId: s.id, paket: pkg2);
      await tablesRepo.addPackageToSession(sessionId: s.id, paket: pkg2);
      await tablesRepo.addPackageToSession(sessionId: s.id, paket: pkg3);

      final s2 = (await session(s.id))!;
      expect(s2.paketTambahan.length, 3);
      expect(s2.paketTambahan.map((p) => p.namaPaket),
          ['Paket 2 Jam', 'Paket 2 Jam', 'Paket 3 Jam']);
      expect(s2.paketTambahanTotal, 50000 + 50000 + 70000);
      expect(s2.waktuSelesaiTarget!.difference(s2.waktuMulai).inMinutes, 60 + 120 + 120 + 180);
      expect(s2.riwayatPerpanjangan, [120, 120, 180]);
    });

    test('2x tambah paket ke sesi BEBAS (tanpa target awal) juga berhasil', () async {
      await seed();
      final t = await table('t1');
      final s = await tablesRepo.startSession(table: t, kasir: kasir, mode: SessionMode.bebas);
      final pkg2 = PlayPackage.fromFirestore(
          'pkg2jam', (await db.collection('packages').doc('pkg2jam').get()).data()!);

      await tablesRepo.addPackageToSession(sessionId: s.id, paket: pkg2);
      await tablesRepo.addPackageToSession(sessionId: s.id, paket: pkg2);

      final s2 = (await session(s.id))!;
      expect(s2.paketTambahan.length, 2);
      // tanpa target sebelumnya → dihitung dari waktuMulai: +120 +120
      expect(s2.waktuSelesaiTarget!.difference(s2.waktuMulai).inMinutes, 240);
    });

    test('paket tarif khusus TIDAK mengubah target selesai', () async {
      await seed();
      final t = await table('t1');
      final s = await tablesRepo.startSession(
        table: t,
        kasir: kasir,
        mode: SessionMode.durasiTetap,
        targetDurationMinutes: 60,
      );
      final pkgVip = PlayPackage.fromFirestore(
          'pkgvip', (await db.collection('packages').doc('pkgvip').get()).data()!);

      await tablesRepo.addPackageToSession(sessionId: s.id, paket: pkgVip);

      final s2 = (await session(s.id))!;
      expect(s2.paketTambahan.length, 1);
      expect(s2.waktuSelesaiTarget!.difference(s2.waktuMulai).inMinutes, 60);
      expect(s2.riwayatPerpanjangan, isEmpty);
    });

    test('batalkan paket tambahan: biaya + durasi dikembalikan', () async {
      await seed();
      final t = await table('t1');
      final s = await tablesRepo.startSession(
        table: t,
        kasir: kasir,
        mode: SessionMode.durasiTetap,
        targetDurationMinutes: 60,
      );
      final pkg2 = PlayPackage.fromFirestore(
          'pkg2jam', (await db.collection('packages').doc('pkg2jam').get()).data()!);
      final pkg3 = PlayPackage.fromFirestore(
          'pkg3jam', (await db.collection('packages').doc('pkg3jam').get()).data()!);

      await tablesRepo.addPackageToSession(sessionId: s.id, paket: pkg2);
      await tablesRepo.addPackageToSession(sessionId: s.id, paket: pkg3);
      final after2 = (await session(s.id))!;
      final toRemove = after2.paketTambahan.firstWhere((p) => p.namaPaket == 'Paket 2 Jam');

      await tablesRepo.removePackageFromSession(sessionId: s.id, addedPackageId: toRemove.id);

      final s3 = (await session(s.id))!;
      expect(s3.paketTambahan.length, 1);
      expect(s3.paketTambahan.first.namaPaket, 'Paket 3 Jam');
      expect(s3.paketTambahanTotal, 70000);
      expect(s3.waktuSelesaiTarget!.difference(s3.waktuMulai).inMinutes, 60 + 180);
    });

    test('batalkan 1 dari 3 paket sama: sisa 2, durasi berkurang 1 unit saja', () async {
      await seed();
      final t = await table('t1');
      final s = await tablesRepo.startSession(
        table: t,
        kasir: kasir,
        mode: SessionMode.durasiTetap,
        targetDurationMinutes: 60,
      );
      final pkg2 = PlayPackage.fromFirestore(
          'pkg2jam', (await db.collection('packages').doc('pkg2jam').get()).data()!);

      await tablesRepo.addPackageToSession(sessionId: s.id, paket: pkg2);
      await tablesRepo.addPackageToSession(sessionId: s.id, paket: pkg2);
      await tablesRepo.addPackageToSession(sessionId: s.id, paket: pkg2);
      final after3 = (await session(s.id))!;
      expect(after3.paketTambahan.length, 3);
      expect(after3.waktuSelesaiTarget!.difference(after3.waktuMulai).inMinutes, 60 + 360);
      expect(after3.riwayatPerpanjangan, [120, 120, 120]);

      // Batalkan SATU unit saja
      await tablesRepo.removePackageFromSession(
        sessionId: s.id,
        addedPackageId: after3.paketTambahan.first.id,
      );

      final s4 = (await session(s.id))!;
      expect(s4.paketTambahan.length, 2);
      expect(s4.paketTambahanTotal, 100000);
      expect(s4.waktuSelesaiTarget!.difference(s4.waktuMulai).inMinutes, 60 + 240);
      expect(s4.riwayatPerpanjangan, [120, 120]);
    });
  });

  group('Grouping paket tambahan (tampilan qty)', () {
    test('paket sama dibeli 2x → satu baris qty 2, beda paket tetap terpisah', () {
      final list = [
        AddedPackage(
          id: '1',
          packageId: 'pkg2jam',
          namaPaket: 'Paket 2 Jam',
          harga: 50000,
          durasiMenit: 120,
          waktuDitambahkan: DateTime(2026, 9, 1),
        ),
        AddedPackage(
          id: '2',
          packageId: 'pkg2jam',
          namaPaket: 'Paket 2 Jam',
          harga: 50000,
          durasiMenit: 120,
          waktuDitambahkan: DateTime(2026, 9, 1),
        ),
        AddedPackage(
          id: '3',
          packageId: 'pkg3jam',
          namaPaket: 'Paket 3 Jam',
          harga: 70000,
          durasiMenit: 180,
          waktuDitambahkan: DateTime(2026, 9, 1),
        ),
      ];

      final groups = groupAddedPackages(list);
      expect(groups.length, 2);

      final pkg2 = groups.firstWhere((g) => g.packageId == 'pkg2jam');
      expect(pkg2.qty, 2);
      expect(pkg2.subtotal, 100000);
      expect(pkg2.entries.length, 2);

      final pkg3 = groups.firstWhere((g) => g.packageId == 'pkg3jam');
      expect(pkg3.qty, 1);
      expect(pkg3.subtotal, 70000);
    });

    test('satu paket saja → qty 1', () {
      final list = [
        AddedPackage(
          id: '1',
          packageId: 'pkg2jam',
          namaPaket: 'Paket 2 Jam',
          harga: 50000,
          durasiMenit: 120,
          waktuDitambahkan: DateTime(2026, 9, 1),
        ),
      ];
      final groups = groupAddedPackages(list);
      expect(groups.single.qty, 1);
      expect(groups.single.subtotal, 50000);
    });
  });

  group('Perpanjang, biaya tambahan, diskon', () {
    test('extendSession menambah target & riwayat', () async {
      await seed();
      final t = await table('t1');
      final s = await tablesRepo.startSession(
        table: t,
        kasir: kasir,
        mode: SessionMode.durasiTetap,
        targetDurationMinutes: 60,
      );
      await tablesRepo.extendSession(sessionId: s.id, additionalMinutes: 30);
      await tablesRepo.extendSession(sessionId: s.id, additionalMinutes: 15);

      final s2 = (await session(s.id))!;
      expect(s2.waktuSelesaiTarget!.difference(s2.waktuMulai).inMinutes, 105);
      expect(s2.riwayatPerpanjangan, [30, 15]);
    });

    test('addExtraCharge mencatat biaya tambahan', () async {
      await seed();
      final t = await table('t1');
      final s = await tablesRepo.startSession(table: t, kasir: kasir, mode: SessionMode.bebas);
      await tablesRepo.addExtraCharge(
        sessionId: s.id,
        nama: 'Sewa stik premium',
        jumlah: 2,
        hargaSatuan: 10000,
        kasirId: kasir.uid,
      );
      final s2 = (await session(s.id))!;
      expect(s2.biayaTambahan.length, 1);
      expect(s2.biayaTambahan.first.subtotal, 20000);
    });

    test('setSessionDiscount menyimpan diskon', () async {
      await seed();
      final t = await table('t1');
      final s = await tablesRepo.startSession(table: t, kasir: kasir, mode: SessionMode.bebas);
      await tablesRepo.setSessionDiscount(
          sessionId: s.id, type: DiscountType.percent, value: 10, reason: 'member');
      final s2 = (await session(s.id))!;
      expect(s2.diskon!.type, DiscountType.percent);
      expect(s2.diskon!.value, 10);
      expect(s2.diskon!.reason, 'member');
    });

    test('finishSession menghitung biaya & mengosongkan meja', () async {
      await seed();
      final t = await table('t1');
      final s = await tablesRepo.startSession(table: t, kasir: kasir, mode: SessionMode.bebas);
      await tablesRepo.addExtraCharge(
        sessionId: s.id,
        nama: 'Ganti bola',
        jumlah: 1,
        hargaSatuan: 15000,
        kasirId: kasir.uid,
      );
      final done = await tablesRepo.finishSession(
        session: (await session(s.id))!,
        ratePerHour: 30000,
        roundingMode: RoundingMode.perMinute,
      );
      expect(done.status, SessionStatus.selesai);
      expect(done.biaya > 0, isTrue);
      final t2 = await table('t1');
      expect(t2.status, TableStatus.kosong);
      expect(t2.currentSessionId, isNull);
    });
  });

  group('Batalkan sesi (tanpa tagihan)', () {
    test('cancelSession: status batal, biaya 0, meja kosong', () async {
      await seed();
      final t = await table('t1');
      final s = await tablesRepo.startSession(table: t, kasir: kasir, mode: SessionMode.bebas);
      final pkg2 = PlayPackage.fromFirestore(
          'pkg2jam', (await db.collection('packages').doc('pkg2jam').get()).data()!);
      await tablesRepo.addPackageToSession(sessionId: s.id, paket: pkg2);

      await tablesRepo.cancelSession(s.id);

      final s2 = (await session(s.id))!;
      expect(s2.status, SessionStatus.batal);
      expect(s2.biaya, 0);
      expect(s2.waktuSelesai, isNotNull);
      expect(s2.durasiMenit, isNotNull);

      final t2 = await table('t1');
      expect(t2.status, TableStatus.kosong);
      expect(t2.currentSessionId, isNull);
    });

    test('cancelSession pada sesi yang sudah selesai = no-op', () async {
      await seed();
      final t = await table('t1');
      final s = await tablesRepo.startSession(table: t, kasir: kasir, mode: SessionMode.bebas);
      await tablesRepo.finishSession(
        session: (await session(s.id))!,
        ratePerHour: 30000,
        roundingMode: RoundingMode.perMinute,
      );
      final done = (await session(s.id))!;
      expect(done.status, SessionStatus.selesai);

      await tablesRepo.cancelSession(s.id);
      final s3 = (await session(s.id))!;
      expect(s3.status, SessionStatus.selesai);
      expect(s3.biaya > 0, isTrue);
    });

    test('sesi batal tidak muncul di stream sesi berjalan', () async {
      await seed();
      final t = await table('t1');
      final s = await tablesRepo.startSession(table: t, kasir: kasir, mode: SessionMode.bebas);
      await tablesRepo.cancelSession(s.id);

      final running = await tablesRepo.runningSessionsStream().first;
      expect(running.where((x) => x.id == s.id), isEmpty);
    });

    test('sesi batal tidak masuk pendapatan meja (riwayat)', () async {
      await seed();
      final t = await table('t1');
      final s = await tablesRepo.startSession(table: t, kasir: kasir, mode: SessionMode.bebas);
      await tablesRepo.cancelSession(s.id);

      final history = await tablesRepo.historyForTable('t1');
      expect(history.length, 1);
      expect(history.single.status, SessionStatus.batal);
      expect(history.single.biaya, 0);
    });
  });

  group('Checkout POS (walk-in)', () {
    test('transaksi berhasil: nomor urut, stok berkurang', () async {
      await seed();
      final p1 = Product.fromFirestore(
          'p1', (await db.collection('products').doc('p1').get()).data()!);
      final p2 = Product.fromFirestore(
          'p2', (await db.collection('products').doc('p2').get()).data()!);
      const settings = AppSettings();

      final tx = await posRepo.createTransaction(
        kasir: kasir,
        items: [
          TransactionItem(
              productId: p1.id, nama: p1.nama, qty: 2, hargaSatuan: p1.harga),
          TransactionItem(
              productId: p2.id, nama: p2.nama, qty: 1, hargaSatuan: p2.harga),
        ],
        settings: settings,
        metodeBayar: PaymentMethod.tunai,
        uangDiterima: 100000,
      );

      expect(tx.nomor, startsWith('INV-'));
      expect(tx.total, 2 * 25000 + 8000);
      expect(tx.kembalian, 100000 - 58000);
      expect(tx.sessionFinalized, isFalse);

      final p1Now = Product.fromFirestore(
          'p1', (await db.collection('products').doc('p1').get()).data()!);
      expect(p1Now.stok, 48);

      final tx2 = await posRepo.createTransaction(
        kasir: kasir,
        items: [
          TransactionItem(
              productId: p2.id, nama: p2.nama, qty: 1, hargaSatuan: p2.harga),
        ],
        settings: settings,
        metodeBayar: PaymentMethod.qris,
      );
      expect(tx2.nomor != tx.nomor, isTrue);
      final lastNum = int.parse(tx2.nomor.substring(tx2.nomor.length - 3));
      expect(lastNum, 2);
    });

    test('diskon + pajak + service charge dihitung benar', () async {
      await seed();
      final p1 = Product.fromFirestore(
          'p1', (await db.collection('products').doc('p1').get()).data()!);
      const settings = AppSettings(pajakPersen: 11, serviceChargePersen: 5);

      final tx = await posRepo.createTransaction(
        kasir: kasir,
        items: [
          TransactionItem(
              productId: p1.id, nama: p1.nama, qty: 4, hargaSatuan: p1.harga),
        ],
        discount: const Discount(type: DiscountType.percent, value: 10),
        settings: settings,
        metodeBayar: PaymentMethod.kartu,
      );

      // subtotal 100000, diskon 10% = 10000, base 90000
      // service 5% = 4500, pajak 11% = 9900 → total 104400
      expect(tx.subtotal, 100000);
      expect(tx.diskon, 10000);
      expect(tx.serviceCharge, 4500);
      expect(tx.pajak, 9900);
      expect(tx.total, 104400);
    });
  });

  group('Checkout gabungan sesi meja + pesanan (alur utama bug report)', () {
    test('sesi + 2 paket tambahan + pesanan → satu transaksi, meja kosong',
        () async {
      await seed();
      final t = await table('t1');
      final s = await tablesRepo.startSession(
        table: t,
        kasir: kasir,
        mode: SessionMode.durasiTetap,
        targetDurationMinutes: 60,
      );
      final pkg2 = PlayPackage.fromFirestore(
          'pkg2jam', (await db.collection('packages').doc('pkg2jam').get()).data()!);
      await tablesRepo.addPackageToSession(sessionId: s.id, paket: pkg2);
      await tablesRepo.addPackageToSession(sessionId: s.id, paket: pkg2);
      final freshSession = (await session(s.id))!;
      expect(freshSession.paketTambahan.length, 2);

      final p1 = Product.fromFirestore(
          'p1', (await db.collection('products').doc('p1').get()).data()!);
      const settings = AppSettings();

      final tx = await posRepo.createTransaction(
        kasir: kasir,
        items: [
          TransactionItem(
              productId: p1.id, nama: p1.nama, qty: 1, hargaSatuan: p1.harga),
        ],
        settings: settings,
        metodeBayar: PaymentMethod.tunai,
        uangDiterima: 200000,
        sessionToFinalize: freshSession,
      );

      // Sesi jalan ±0 menit → sewa per 15 menit minimal 1 blok = 7500
      // + paket tambahan 100000 = 107500 sesi; pesanan 25000 → total 132500
      expect(tx.sessionFinalized, isTrue);
      expect(tx.total, tx.subtotal + (await session(s.id))!.biaya);

      final sDone = (await session(s.id))!;
      expect(sDone.status, SessionStatus.selesai);
      expect(sDone.biaya, 107500);
      expect(sDone.invoiceId, tx.id);

      final tNow = await table('t1');
      expect(tNow.status, TableStatus.kosong);
      expect(tNow.currentSessionId, isNull);
    });

    test('checkout paket flat + paket tambahan: sewa = harga paket flat',
        () async {
      await seed();
      final t = await table('t1');
      final pkg2 = PlayPackage.fromFirestore(
          'pkg2jam', (await db.collection('packages').doc('pkg2jam').get()).data()!);
      final s = await tablesRepo.startSession(
        table: t,
        kasir: kasir,
        mode: SessionMode.bebas,
        paket: pkg2,
        paketNama: pkg2.namaPaket,
      );
      await tablesRepo.addPackageToSession(sessionId: s.id, paket: pkg2);
      final freshSession = (await session(s.id))!;
      const settings = AppSettings();

      final tx = await posRepo.createTransaction(
        kasir: kasir,
        items: const [],
        settings: settings,
        metodeBayar: PaymentMethod.qris,
        sessionToFinalize: freshSession,
      );

      final sDone = (await session(s.id))!;
      // paket flat pertama 50000 + paket tambahan 50000 = 100000
      expect(sDone.biaya, 100000);
      expect(tx.total, 100000);
    });
  });
}
