import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/domain/app_user.dart';
import '../../settings/domain/settings_models.dart';
import '../../../core/domain/billing_calculator.dart';
import '../domain/package_models.dart';
import '../domain/table_models.dart';

class TablesRepository {
  final FirebaseFirestore _db;

  TablesRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  Stream<List<BillTable>> tablesStream() {
    return _db
        .collection('tables')
        .orderBy('nama_meja')
        .snapshots()
        .map((snap) => snap.docs.map((d) => BillTable.fromFirestore(d.id, d.data())).toList());
  }

  /// Sesi yang sedang berjalan di semua meja (untuk dashboard & alert).
  Stream<List<TableSession>> runningSessionsStream() {
    return _db
        .collection('table_sessions')
        .where('status', isEqualTo: 'berjalan')
        .snapshots()
        .map((snap) => snap.docs.map((d) => TableSession.fromFirestore(d.id, d.data())).toList());
  }

  Stream<List<PlayPackage>> packagesStream() {
    return _db
        .collection('packages')
        .orderBy('nama_paket')
        .snapshots()
        .map((snap) => snap.docs.map((d) => PlayPackage.fromFirestore(d.id, d.data())).toList());
  }

  Future<TableSession?> sessionById(String sessionId) async {
    final snap = await _db.collection('table_sessions').doc(sessionId).get();
    if (!snap.exists) return null;
    return TableSession.fromFirestore(snap.id, snap.data()!);
  }

  Future<BillTable?> tableById(String tableId) async {
    final snap = await _db.collection('tables').doc(tableId).get();
    if (!snap.exists) return null;
    return BillTable.fromFirestore(snap.id, snap.data()!);
  }

  /// Memulai sesi baru. Gunakan Firestore transaction supaya dua device
  /// tidak bisa memulai sesi di meja yang sama secara bersamaan (race condition).
  Future<TableSession> startSession({
    required BillTable table,
    required AppUser kasir,
    required SessionMode mode,
    int? targetDurationMinutes, // untuk durasi_tetap (bukan paket flat)
    PlayPackage? paket,
    String? paketNama,
  }) async {
    final now = DateTime.now();
    final isFlat = paket?.tipe == PackageType.durasiFlat;
    final sessionRef = _db.collection('table_sessions').doc();
    final tableRef = _db.collection('tables').doc(table.id);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(tableRef);
      final current = BillTable.fromFirestore(tableRef.id, snap.data()!);
      if (!current.isAvailable) {
        throw StateError('Meja ${current.namaMeja} sedang ${current.status.label.toLowerCase()} — tidak bisa memulai sesi.');
      }
      final session = TableSession(
        id: sessionRef.id,
        tableId: table.id,
        tableName: table.namaMeja,
        waktuMulai: now,
        kasirId: kasir.uid,
        kasirNama: kasir.nama,
        status: SessionStatus.berjalan,
        mode: isFlat ? SessionMode.durasiTetap : mode,
        waktuSelesaiTarget: isFlat && paket!.durasiMenit != null
            ? now.add(Duration(minutes: paket.durasiMenit!))
            : (mode == SessionMode.durasiTetap && targetDurationMinutes != null
                ? now.add(Duration(minutes: targetDurationMinutes))
                : null),
        packageId: paket?.id,
        packageName: paketNama,
      );
      tx.set(sessionRef, session.toMap());
      tx.update(tableRef, {
        'status': TableStatus.terpakai.storageValue,
        'current_session_id': sessionRef.id,
      });
    });

    final created = await sessionById(sessionRef.id);
    return created!;
  }

  /// Selesaikan sesi: hitung biaya final (pure function), simpan, kosongkan meja.
  Future<TableSession> finishSession({
    required TableSession session,
    required int ratePerHour,
    required RoundingMode roundingMode,
  }) async {
    final now = DateTime.now();
    final elapsed = session.elapsedAt(now);

    // Paket durasi flat: biaya sewa = harga paket (bukan hitung per menit).
    // Paket tambahan (dibeli saat sesi berjalan) dijumlahkan terpisah.
    final flatPrice = await _flatPackagePrice(session);
    final bill = calculateSessionBill(
      elapsed: elapsed,
      ratePerHour: ratePerHour,
      mode: roundingMode,
      extraCharges: session.biayaTambahan,
      addedPackagesTotal: session.paketTambahanTotal,
      discount: session.diskon,
      flatPackagePrice: flatPrice,
    );

    await _db.runTransaction((tx) async {
      final tableRef = _db.collection('tables').doc(session.tableId);
      // ===== FASE READ: semua read wajib SEBELUM write dalam transaksi =====
      final snap = await tx.get(tableRef);

      tx.update(_db.collection('table_sessions').doc(session.id), {
        'status': SessionStatus.selesai.storageValue,
        'waktu_selesai': Timestamp.fromDate(now),
        'durasi_menit': elapsed.inMinutes,
        'biaya': bill.subtotal,
      });
      if (snap.exists) {
        final t = BillTable.fromFirestore(tableRef.id, snap.data()!);
        // Hanya kosongkan bila meja masih menunjuk sesi ini (ada kemungkinan
        // sesi lain sudah dimulai ulang oleh device lain).
        if (t.currentSessionId == session.id) {
          tx.update(tableRef, {
            'status': TableStatus.kosong.storageValue,
            'current_session_id': FieldValue.delete(),
          });
        }
      }
    });
    return (await sessionById(session.id))!;
  }

  Future<int?> _flatPackagePrice(TableSession session) async {
    if (session.packageId == null) return null;
    final snap = await _db.collection('packages').doc(session.packageId!).get();
    if (!snap.exists) return null;
    final p = PlayPackage.fromFirestore(snap.id, snap.data()!);
    if (p.tipe == PackageType.durasiFlat) return p.harga;
    return null;
  }

  /// Perpanjang sesi durasi tetap.
  Future<void> extendSession({
    required String sessionId,
    required int additionalMinutes,
  }) async {
    final ref = _db.collection('table_sessions').doc(sessionId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final s = TableSession.fromFirestore(sessionId, snap.data()!);
      if (!s.isRunning) return;
      final oldTarget = s.waktuSelesaiTarget ?? s.waktuMulai;
      final newTarget = oldTarget.add(Duration(minutes: additionalMinutes));
      tx.update(ref, {
        'waktu_selesai_target': Timestamp.fromDate(newTarget),
        'riwayat_perpanjangan': [...s.riwayatPerpanjangan, additionalMinutes],
        'is_alert_triggered': false,
      });
    });
  }

  /// Tambah PAKET saat sesi sedang berjalan: durasi bertambah sesuai paket
  /// (misal beli "Paket 3 Jam" di tengah sesi → waktu_selesai_target + 3 jam)
  /// dan harga paket dicatat di `paket_tambahan` (masuk ke breakdown biaya).
  ///
  /// [TableSession] mencatat tiap pembelian sebagai entri terpisah supaya
  /// bisa dibatalkan satu per satu.
  static int _packageSeq = 0;

  Future<void> addPackageToSession({
    required String sessionId,
    required PlayPackage paket,
  }) async {
    final ref = _db.collection('table_sessions').doc(sessionId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final s = TableSession.fromFirestore(sessionId, snap.data()!);
      if (!s.isRunning) return;

      // id unik per pembelian: microsecond + urutan + id paket, supaya dua
      // pembelian yang hampir bersamaan tidak menghasilkan id yang sama.
      final added = AddedPackage(
        id: '${DateTime.now().microsecondsSinceEpoch}-${_packageSeq++}-${paket.id}',
        packageId: paket.id,
        namaPaket: paket.namaPaket,
        harga: paket.harga,
        durasiMenit: paket.durasiMenit,
        waktuDitambahkan: DateTime.now(),
      );

      final updates = <String, dynamic>{
        'paket_tambahan': [
          ...s.paketTambahan.map((p) => p.toMap()),
          added.toMap(),
        ],
        'is_alert_triggered': false,
      };

      // Paket durasi flat menambah waktu selesai target.
      if (paket.tipe == PackageType.durasiFlat && paket.durasiMenit != null) {
        final oldTarget = s.waktuSelesaiTarget ?? s.waktuMulai;
        updates['waktu_selesai_target'] =
            Timestamp.fromDate(oldTarget.add(Duration(minutes: paket.durasiMenit!)));
        updates['riwayat_perpanjangan'] = [...s.riwayatPerpanjangan, paket.durasiMenit!];
      }

      tx.update(ref, updates);
    });
  }

  /// Batalkan paket tambahan yang dibeli di tengah sesi:
  /// hapus SATU entri dari tagihan, kembalikan durasi yang ditambahkan
  /// (bila durasi flat), dan hapus satu entri dari riwayat perpanjangan.
  Future<void> removePackageFromSession({
    required String sessionId,
    required String addedPackageId,
  }) async {
    final ref = _db.collection('table_sessions').doc(sessionId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final s = TableSession.fromFirestore(sessionId, snap.data()!);
      if (!s.isRunning) return;
      final idx = s.paketTambahan.indexWhere((p) => p.id == addedPackageId);
      if (idx < 0) return;
      final target = s.paketTambahan[idx];

      final updates = <String, dynamic>{
        'paket_tambahan': [
          for (var i = 0; i < s.paketTambahan.length; i++)
            if (i != idx) s.paketTambahan[i].toMap(),
        ],
      };

      // Kembalikan durasi yang ditambahkan paket durasi flat ke target selesai.
      if (target.durasiMenit != null && s.waktuSelesaiTarget != null) {
        updates['waktu_selesai_target'] =
            Timestamp.fromDate(s.waktuSelesaiTarget!.subtract(Duration(minutes: target.durasiMenit!)));
        final idx = s.riwayatPerpanjangan.indexOf(target.durasiMenit!);
        if (idx >= 0) {
          final riwayat = [...s.riwayatPerpanjangan]..removeAt(idx);
          updates['riwayat_perpanjangan'] = riwayat;
        }
      }

      tx.update(ref, updates);
    });
  }

  Future<void> setAlertTriggered(String sessionId) async {
    await _db.collection('table_sessions').doc(sessionId).update({'is_alert_triggered': true});
  }

  /// Batalkan sesi yang sedang berjalan TANPA tagihan (mis. pelanggan batal
  /// main atau sesi salah start). Sesi ditandai `batal` dengan biaya 0,
  /// dan meja dikosongkan.
  Future<void> cancelSession(String sessionId) async {
    final sessionRef = _db.collection('table_sessions').doc(sessionId);
    await _db.runTransaction((tx) async {
      // ===== FASE READ: semua read wajib SEBELUM write =====
      final snap = await tx.get(sessionRef);
      if (!snap.exists) return;
      final s = TableSession.fromFirestore(sessionId, snap.data()!);
      if (!s.isRunning) return;

      final tableRef = _db.collection('tables').doc(s.tableId);
      final tableSnap = await tx.get(tableRef);

      final now = DateTime.now();
      tx.update(sessionRef, {
        'status': SessionStatus.batal.storageValue,
        'waktu_selesai': Timestamp.fromDate(now),
        'durasi_menit': s.elapsedAt(now).inMinutes,
        'biaya': 0,
      });
      if (tableSnap.exists) {
        final t = BillTable.fromFirestore(s.tableId, tableSnap.data()!);
        // Hanya kosongkan bila meja masih menunjuk sesi ini.
        if (t.currentSessionId == sessionId) {
          tx.update(tableRef, {
            'status': TableStatus.kosong.storageValue,
            'current_session_id': FieldValue.delete(),
          });
        }
      }
    });
  }

  Future<void> addExtraCharge({
    required String sessionId,
    required String nama,
    required int jumlah,
    required int hargaSatuan,
    required String kasirId,
  }) async {
    final ref = _db.collection('table_sessions').doc(sessionId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final s = TableSession.fromFirestore(sessionId, snap.data()!);
      if (!s.isRunning) return;
      final newCharge = ExtraCharge(
        nama: nama,
        jumlah: jumlah,
        hargaSatuan: hargaSatuan,
        ditambahkanOleh: kasirId,
        waktuDitambahkan: DateTime.now(),
      );
      tx.update(ref, {
        'biaya_tambahan': [
          ...s.biayaTambahan.map((c) => c.toMap()),
          newCharge.toMap(),
        ],
      });
    });
  }

  Future<void> setSessionDiscount({
    required String sessionId,
    required DiscountType type,
    required int value,
    String? reason,
  }) async {
    final discount = Discount(type: type, value: value, reason: reason);
    await _db.collection('table_sessions').doc(sessionId).update({'diskon': discount.toMap()});
  }

  Future<void> setTableReserved(BillTable table, bool reserved) async {
    final ref = _db.collection('tables').doc(table.id);
    await ref.update({
      'status': reserved ? TableStatus.reserved.storageValue : TableStatus.kosong.storageValue,
    });
  }

  Future<void> saveTable({
    String? id,
    required String namaMeja,
    required int tarifPerJam,
    required RoundingMode pembulatan,
  }) async {
    final data = BillTable(
      id: id ?? '',
      namaMeja: namaMeja,
      tarifPerJam: tarifPerJam,
      status: TableStatus.kosong,
      metodePembulatan: pembulatan,
    ).toMap();
    if (id == null) {
      await _db.collection('tables').add(data);
    } else {
      await _db.collection('tables').doc(id).update({
        'nama_meja': namaMeja,
        'tarif_per_jam': tarifPerJam,
        'metode_pembulatan': pembulatan.storageValue,
      });
    }
  }

  Future<void> deleteTable(String id) => _db.collection('tables').doc(id).delete();

  Future<void> savePackage(PlayPackage paket) async {
    if (paket.id.isEmpty) {
      await _db.collection('packages').add(paket.toMap());
    } else {
      await _db.collection('packages').doc(paket.id).set(paket.toMap(), SetOptions(merge: true));
    }
  }

  Future<void> deletePackage(String id) => _db.collection('packages').doc(id).delete();

  Future<List<TableSession>> historyForTable(String tableId, {int limit = 50}) async {
    final snap = await _db
        .collection('table_sessions')
        .where('table_id', isEqualTo: tableId)
        .orderBy('waktu_mulai', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => TableSession.fromFirestore(d.id, d.data())).toList();
  }

  /// Seed data demo: meja, kategori, produk, paket. Idempotent (cek keberadaan).
  Future<void> seedDemoData({required AppSettings settings}) async {
    final batch = _db.batch();

    // Meja: 8 meja dengan 2 tipe tarif
    for (var i = 1; i <= 8; i++) {
      final tarif = i <= 6 ? 30000 : 50000;
      final nama = i <= 6 ? 'Meja $i' : 'VIP $i';
      final ref = _db.collection('tables').doc('demo_table_$i');
      batch.set(ref, {
        'nama_meja': nama,
        'tarif_per_jam': tarif,
        'status': 'kosong',
        'metode_pembulatan': settings.pembulatan.storageValue,
      });
    }

    // Kategori
    final catMakanan = _db.collection('categories').doc('demo_cat_makanan');
    final catMinuman = _db.collection('categories').doc('demo_cat_minuman');
    final catSnack = _db.collection('categories').doc('demo_cat_snack');
    batch.set(catMakanan, {'nama': 'Makanan'});
    batch.set(catMinuman, {'nama': 'Minuman'});
    batch.set(catSnack, {'nama': 'Snack'});

    // Produk
    void product(String id, String nama, DocumentReference cat, int harga, int stok) {
      batch.set(_db.collection('products').doc(id), {
        'nama': nama,
        'kategori_id': cat.id,
        'harga': harga,
        'stok': stok,
      });
    }

    product('demo_p1', 'Nasi Goreng Spesial', catMakanan, 25000, 50);
    product('demo_p2', 'Mie Goreng', catMakanan, 22000, 50);
    product('demo_p3', 'Kentang Goreng', catSnack, 18000, 40);
    product('demo_p4', 'Aneka Sate', catMakanan, 30000, 30);
    product('demo_p5', 'Air Mineral', catMinuman, 5000, 100);
    product('demo_p6', 'Es Teh Manis', catMinuman, 8000, 80);
    product('demo_p7', 'Teh Botol', catMinuman, 7000, 80);
    product('demo_p8', 'Kopi Hitam', catMinuman, 12000, 60);
    product('demo_p9', 'Es Jeruk', catMinuman, 10000, 60);
    product('demo_p10', 'Keripik Singkong', catSnack, 10000, 40);
    product('demo_p11', 'Pisang Goreng', catSnack, 12000, 40);
    product('demo_p12', 'Roti Bakar Coklat', catSnack, 15000, 40);

    // Paket
    batch.set(_db.collection('packages').doc('demo_pkg_2jam'), {
      'nama_paket': 'Paket 2 Jam',
      'tipe': 'durasi_flat',
      'durasi_menit': 120,
      'harga': 50000,
      'hari_aktif': [],
      'berlaku_untuk_meja': [],
      'is_active': true,
    });
    batch.set(_db.collection('packages').doc('demo_pkg_weekday'), {
      'nama_paket': 'Paket Weekday',
      'tipe': 'tarif_khusus',
      'harga': 25000,
      'hari_aktif': [1, 2, 3, 4, 5],
      'berlaku_untuk_meja': [],
      'is_active': true,
    });

    await batch.commit();
  }
}