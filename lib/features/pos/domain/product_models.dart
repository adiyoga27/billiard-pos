import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String id;
  final String nama;

  const Category({required this.id, required this.nama});

  factory Category.fromFirestore(String id, Map<String, dynamic> map) =>
      Category(id: id, nama: map['nama'] as String? ?? '');

  Map<String, dynamic> toMap() => {'nama': nama};
}

class Product {
  final String id;
  final String nama;
  final String kategoriId;
  final int harga;
  final int stok;
  final String? gambarUrl;

  const Product({
    required this.id,
    required this.nama,
    required this.kategoriId,
    required this.harga,
    required this.stok,
    this.gambarUrl,
  });

  bool get outOfStock => stok <= 0;

  factory Product.fromFirestore(String id, Map<String, dynamic> map) => Product(
        id: id,
        nama: map['nama'] as String? ?? '',
        kategoriId: map['kategori_id'] as String? ?? '',
        harga: (map['harga'] as num?)?.toInt() ?? 0,
        stok: (map['stok'] as num?)?.toInt() ?? 0,
        gambarUrl: map['gambar_url'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'nama': nama,
        'kategori_id': kategoriId,
        'harga': harga,
        'stok': stok,
        if (gambarUrl != null) 'gambar_url': gambarUrl,
      };
}

class TransactionItem {
  final String productId;
  final String nama;
  final int qty;
  final int hargaSatuan;

  const TransactionItem({
    required this.productId,
    required this.nama,
    required this.qty,
    required this.hargaSatuan,
  });

  int get subtotal => qty * hargaSatuan;

  factory TransactionItem.fromMap(Map<String, dynamic> map) => TransactionItem(
        productId: map['product_id'] as String? ?? '',
        nama: map['nama'] as String? ?? '',
        qty: (map['qty'] as num?)?.toInt() ?? 0,
        hargaSatuan: (map['harga_satuan'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'nama': nama,
        'qty': qty,
        'harga_satuan': hargaSatuan,
        'subtotal': subtotal,
      };
}

enum PaymentMethod { tunai, qris, kartu }

extension PaymentMethodX on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.tunai => 'Tunai',
        PaymentMethod.qris => 'QRIS',
        PaymentMethod.kartu => 'Kartu',
      };

  String get storageValue => switch (this) {
        PaymentMethod.tunai => 'tunai',
        PaymentMethod.qris => 'qris',
        PaymentMethod.kartu => 'kartu',
      };

  String get icon => switch (this) {
        PaymentMethod.tunai => '💵',
        PaymentMethod.qris => '📱',
        PaymentMethod.kartu => '💳',
      };

  static PaymentMethod fromStorage(String? v) => switch (v) {
        'qris' => PaymentMethod.qris,
        'kartu' => PaymentMethod.kartu,
        _ => PaymentMethod.tunai,
      };
}

class Transaction {
  final String id;
  final String nomor; // INV-20260901025 (INV + tanggal + urutan hari itu)
  final String kasirId;
  final String? kasirNama;
  final String? tableSessionId;
  final String? tableName;
  final int subtotal;
  final int diskon;
  final int pajak;
  final int serviceCharge;
  final int total;
  final PaymentMethod metodeBayar;
  final int? uangDiterima;
  final int? kembalian;
  final DateTime createdAt;
  final List<TransactionItem> items;
  final bool sessionFinalized; // sesi meja ikut difinalisasi di transaksi ini

  const Transaction({
    required this.id,
    required this.nomor,
    required this.kasirId,
    this.kasirNama,
    this.tableSessionId,
    this.tableName,
    required this.subtotal,
    required this.diskon,
    required this.pajak,
    required this.serviceCharge,
    required this.total,
    required this.metodeBayar,
    this.uangDiterima,
    this.kembalian,
    required this.createdAt,
    required this.items,
    this.sessionFinalized = false,
  });

  int get itemCount => items.fold(0, (acc, i) => acc + i.qty);

  factory Transaction.fromFirestore(String id, Map<String, dynamic> map) => Transaction(
        id: id,
        nomor: map['nomor'] as String? ?? id,
        kasirId: map['kasir_id'] as String? ?? '',
        kasirNama: map['kasir_nama'] as String?,
        tableSessionId: map['table_session_id'] as String?,
        tableName: map['table_name'] as String?,
        subtotal: (map['subtotal'] as num?)?.toInt() ?? 0,
        diskon: (map['diskon'] as num?)?.toInt() ?? 0,
        pajak: (map['pajak'] as num?)?.toInt() ?? 0,
        serviceCharge: (map['service_charge'] as num?)?.toInt() ?? 0,
        total: (map['total'] as num?)?.toInt() ?? 0,
        metodeBayar: PaymentMethodX.fromStorage(map['metode_bayar'] as String?),
        uangDiterima: (map['uang_diterima'] as num?)?.toInt(),
        kembalian: (map['kembalian'] as num?)?.toInt(),
        createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        items: (map['items'] as List?)
                ?.map((e) => TransactionItem.fromMap(e as Map<String, dynamic>))
                .toList() ??
            const [],
        sessionFinalized: map['session_finalized'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'nomor': nomor,
        'kasir_id': kasirId,
        if (kasirNama != null) 'kasir_nama': kasirNama,
        if (tableSessionId != null) 'table_session_id': tableSessionId,
        if (tableName != null) 'table_name': tableName,
        'subtotal': subtotal,
        'diskon': diskon,
        'pajak': pajak,
        'service_charge': serviceCharge,
        'total': total,
        'metode_bayar': metodeBayar.storageValue,
        if (uangDiterima != null) 'uang_diterima': uangDiterima,
        if (kembalian != null) 'kembalian': kembalian,
        'created_at': Timestamp.fromDate(createdAt),
        'items': items.map((e) => e.toMap()).toList(),
        'session_finalized': sessionFinalized,
      };
}