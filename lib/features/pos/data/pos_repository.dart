import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

import '../../../core/domain/billing_calculator.dart';
import '../../auth/domain/app_user.dart';
import '../../settings/domain/settings_models.dart';
import '../../tables/domain/table_models.dart';
import '../domain/product_models.dart';

class PosRepository {
  final FirebaseFirestore _db;

  PosRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  Stream<List<Category>> categoriesStream() {
    return _db
        .collection('categories')
        .orderBy('nama')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Category.fromFirestore(d.id, d.data())).toList());
  }

  Stream<List<Product>> productsStream() {
    return _db
        .collection('products')
        .orderBy('nama')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Product.fromFirestore(d.id, d.data())).toList());
  }

  Future<void> saveCategory(String? id, String nama) async {
    if (id == null) {
      await _db.collection('categories').add({'nama': nama});
    } else {
      await _db.collection('categories').doc(id).update({'nama': nama});
    }
  }

  Future<void> deleteCategory(String id) async {
    // Hapus produk yang memakai kategori ini juga
    final products = await _db
        .collection('products')
        .where('kategori_id', isEqualTo: id)
        .get();
    final batch = _db.batch();
    for (final p in products.docs) {
      batch.delete(p.reference);
    }
    batch.delete(_db.collection('categories').doc(id));
    await batch.commit();
  }

  Future<void> saveProduct({
    String? id,
    required String nama,
    required String kategoriId,
    required int harga,
    required int stok,
    String? gambarUrl,
  }) async {
    final data = {
      'nama': nama,
      'kategori_id': kategoriId,
      'harga': harga,
      'stok': stok,
      'gambar_url': ?gambarUrl,
    };
    if (id == null) {
      await _db.collection('products').add(data);
    } else {
      await _db.collection('products').doc(id).update(data);
    }
  }

  Future<void> deleteProduct(String id) => _db.collection('products').doc(id).delete();

  Stream<List<Transaction>> transactionsStream({int limit = 100}) {
    return _db
        .collection('transactions')
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Transaction.fromFirestore(d.id, d.data())).toList());
  }

  Future<Transaction?> transactionByNomor(String nomor) async {
    final snap = await _db.collection('transactions').where('nomor', isEqualTo: nomor).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return Transaction.fromFirestore(d.id, d.data());
  }

  /// Buat transaksi POS (bisa digabung dengan finalisasi sesi meja).
  /// Semua dalam SATU runTransaction: bikin nomor invoice berurutan,
  /// kurangi stok, finalisasi sesi + kosongkan meja bila menyertakan sesi.
  Future<Transaction> createTransaction({
    required AppUser kasir,
    required List<TransactionItem> items,
    Discount? discount,
    required AppSettings settings,
    required PaymentMethod metodeBayar,
    int? uangDiterima,
    TableSession? sessionToFinalize, // sesi meja yang ikut ditagih
  }) async {
    final subtotal = items.fold<int>(0, (acc, i) => acc + i.subtotal);
    final totals = calculateTransactionTotals(
      subtotal: subtotal,
      discount: discount,
      taxPercent: settings.pajakPersen,
      serviceChargePercent: settings.serviceChargePersen,
    );

    final invoiceRef = _db.collection('transactions').doc();
    late Transaction txDoc;

    await _db.runTransaction((tx) async {
      final now = DateTime.now();
      final dateKey = '${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';
      final counterRef = _db.collection('counters').doc(dateKey);

      // ===== FASE READ (semua read wajib sebelum write dalam transaksi) =====
      final counterSnap = await tx.get(counterRef);

      DocumentSnapshot<Map<String, dynamic>>? sessionSnap;
      DocumentSnapshot<Map<String, dynamic>>? tableSnap;
      DocumentSnapshot<Map<String, dynamic>>? flatPkgSnap;
      if (sessionToFinalize != null) {
        final sessionRef = _db.collection('table_sessions').doc(sessionToFinalize.id);
        sessionSnap = await tx.get(sessionRef);
        if (sessionSnap.exists) {
          final session = TableSession.fromFirestore(sessionToFinalize.id, sessionSnap.data()!);
          tableSnap = await tx.get(_db.collection('tables').doc(session.tableId));
          if (session.packageId != null) {
            flatPkgSnap = await tx.get(_db.collection('packages').doc(session.packageId!));
          }
        }
      }

      final productSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final item in items) {
        productSnaps[item.productId] =
            await tx.get(_db.collection('products').doc(item.productId));
      }

      // ===== FASE WRITE =====
      final lastNumber = (counterSnap.data()?['last_invoice'] as num?)?.toInt() ?? 0;
      final newNumber = lastNumber + 1;
      tx.set(counterRef, {'last_invoice': newNumber}, SetOptions(merge: true));
      final nomor = 'INV-$dateKey${newNumber.toString().padLeft(3, '0')}';

      int sessionBillAmount = 0;
      if (sessionToFinalize != null && sessionSnap != null && sessionSnap.exists) {
        final sessionRef = _db.collection('table_sessions').doc(sessionToFinalize.id);
        final session = TableSession.fromFirestore(sessionToFinalize.id, sessionSnap.data()!);
        final elapsed = session.elapsedAt(now);
        final table = (tableSnap != null && tableSnap.exists)
            ? BillTable.fromFirestore(session.tableId, tableSnap.data()!)
            : null;
        final flatPrice = flatPkgSnap != null && flatPkgSnap.exists
            ? (flatPkgSnap.data()!['tipe'] == 'durasi_flat'
                ? (flatPkgSnap.data()!['harga'] as num?)?.toInt()
                : null)
            : null;
        final bill = calculateSessionBill(
          elapsed: elapsed,
          ratePerHour: table?.tarifPerJam ?? 0,
          mode: table?.metodePembulatan ?? RoundingMode.perMinute,
          extraCharges: session.biayaTambahan,
          addedPackagesTotal: session.paketTambahanTotal,
          discount: session.diskon,
          flatPackagePrice: flatPrice,
        );
        sessionBillAmount = bill.subtotal;
        tx.update(sessionRef, {
          'status': 'selesai',
          'waktu_selesai': Timestamp.fromDate(now),
          'durasi_menit': elapsed.inMinutes,
          'biaya': bill.subtotal,
          'invoice_id': invoiceRef.id,
        });
        if (tableSnap != null &&
            tableSnap.exists &&
            (tableSnap.data()?['current_session_id'] as String?) == session.id) {
          tx.update(_db.collection('tables').doc(session.tableId), {
            'status': 'kosong',
            'current_session_id': FieldValue.delete(),
          });
        }
      }

      txDoc = Transaction(
        id: invoiceRef.id,
        nomor: nomor,
        kasirId: kasir.uid,
        kasirNama: kasir.nama,
        tableSessionId: sessionToFinalize?.id,
        tableName: sessionToFinalize?.tableName,
        subtotal: totals.subtotal,
        diskon: totals.discountAmount,
        pajak: totals.taxAmount,
        serviceCharge: totals.serviceChargeAmount,
        total: totals.total + sessionBillAmount,
        metodeBayar: metodeBayar,
        uangDiterima: uangDiterima,
        kembalian: uangDiterima != null && metodeBayar == PaymentMethod.tunai
            ? uangDiterima - (totals.total + sessionBillAmount)
            : null,
        createdAt: now,
        items: items,
        sessionFinalized: sessionToFinalize != null,
      );
      tx.set(invoiceRef, txDoc.toMap());

      for (final item in items) {
        final pSnap = productSnaps[item.productId];
        if (pSnap != null && pSnap.exists) {
          final stok = (pSnap.data()?['stok'] as num?)?.toInt() ?? 0;
          tx.update(_db.collection('products').doc(item.productId), {
            'stok': (stok - item.qty).clamp(0, 999999),
          });
        }
      }
    });

    return txDoc;
  }
}