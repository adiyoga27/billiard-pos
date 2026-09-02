import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/domain/billing_calculator.dart';

/// Status meja billiard.
enum TableStatus { kosong, terpakai, reserved }

extension TableStatusX on TableStatus {
  String get label => switch (this) {
        TableStatus.kosong => 'Kosong',
        TableStatus.terpakai => 'Terpakai',
        TableStatus.reserved => 'Reserved',
      };

  String get storageValue => switch (this) {
        TableStatus.kosong => 'kosong',
        TableStatus.terpakai => 'terpakai',
        TableStatus.reserved => 'reserved',
      };

  static TableStatus fromStorage(String? v) => switch (v) {
        'terpakai' => TableStatus.terpakai,
        'reserved' => TableStatus.reserved,
        _ => TableStatus.kosong,
      };
}

class BillTable {
  final String id;
  final String namaMeja;
  final int tarifPerJam;
  final TableStatus status;
  final RoundingMode metodePembulatan;
  final String? currentSessionId;

  const BillTable({
    required this.id,
    required this.namaMeja,
    required this.tarifPerJam,
    required this.status,
    required this.metodePembulatan,
    this.currentSessionId,
  });

  bool get isAvailable => status == TableStatus.kosong;

  BillTable copyWith({
    String? namaMeja,
    int? tarifPerJam,
    TableStatus? status,
    RoundingMode? metodePembulatan,
    String? currentSessionId,
    bool clearSession = false,
  }) {
    return BillTable(
      id: id,
      namaMeja: namaMeja ?? this.namaMeja,
      tarifPerJam: tarifPerJam ?? this.tarifPerJam,
      status: status ?? this.status,
      metodePembulatan: metodePembulatan ?? this.metodePembulatan,
      currentSessionId: clearSession ? null : (currentSessionId ?? this.currentSessionId),
    );
  }

  factory BillTable.fromFirestore(String id, Map<String, dynamic> map) => BillTable(
        id: id,
        namaMeja: map['nama_meja'] as String? ?? 'Meja',
        tarifPerJam: (map['tarif_per_jam'] as num?)?.toInt() ?? 0,
        status: TableStatusX.fromStorage(map['status'] as String?),
        metodePembulatan: RoundingModeX.fromStorage(map['metode_pembulatan'] as String?),
        currentSessionId: map['current_session_id'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'nama_meja': namaMeja,
        'tarif_per_jam': tarifPerJam,
        'status': status.storageValue,
        'metode_pembulatan': metodePembulatan.storageValue,
        'current_session_id': currentSessionId,
      };
}

/// Mode sesi: bebas (billing per menit dari durasi aktual) atau durasi tetap (punya waktu selesai target).
enum SessionMode { bebas, durasiTetap }

extension SessionModeX on SessionMode {
  String get label => this == SessionMode.bebas ? 'Bebas' : 'Durasi tetap';

  String get storageValue => this == SessionMode.bebas ? 'bebas' : 'durasi_tetap';

  static SessionMode fromStorage(String? v) => v == 'durasi_tetap' ? SessionMode.durasiTetap : SessionMode.bebas;
}

enum SessionStatus { berjalan, selesai }

extension SessionStatusX on SessionStatus {
  String get storageValue => this == SessionStatus.berjalan ? 'berjalan' : 'selesai';

  static SessionStatus fromStorage(String? v) => v == 'selesai' ? SessionStatus.selesai : SessionStatus.berjalan;
}

/// Paket yang ditambahkan KETIKA sesi sedang berjalan (menambah durasi &
/// menambah biaya). Misal beli "Paket 3 Jam" di tengah sesi → target + 3 jam.
class AddedPackage {
  final String id; // unik per pembelian, dipakai untuk membatalkan
  final String packageId;
  final String namaPaket;
  final int harga;
  final int? durasiMenit; // durasi yang ditambahkan ke target (bila durasi flat)
  final DateTime waktuDitambahkan;

  const AddedPackage({
    required this.id,
    required this.packageId,
    required this.namaPaket,
    required this.harga,
    this.durasiMenit,
    required this.waktuDitambahkan,
  });

  factory AddedPackage.fromMap(Map<String, dynamic> map) {
    final raw = map['waktu_ditambahkan'];
    return AddedPackage(
      id: map['id'] as String? ?? '',
      packageId: map['package_id'] as String? ?? '',
      namaPaket: map['nama_paket'] as String? ?? 'Paket',
      harga: (map['harga'] as num?)?.toInt() ?? 0,
      durasiMenit: (map['durasi_menit'] as num?)?.toInt(),
      waktuDitambahkan: raw is Timestamp
          ? raw.toDate()
          : raw is DateTime
              ? raw
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'package_id': packageId,
        'nama_paket': namaPaket,
        'harga': harga,
        if (durasiMenit != null) 'durasi_menit': durasiMenit,
        'waktu_ditambahkan': Timestamp.fromDate(waktuDitambahkan),
      };
}

class TableSession {
  final String id;
  final String tableId;
  final String? tableName;
  final DateTime waktuMulai;
  final DateTime? waktuSelesai;
  final int? durasiMenit;
  final int biaya; // biaya final saat selesai
  final String kasirId;
  final String? kasirNama;
  final SessionStatus status;
  final SessionMode mode;
  final DateTime? waktuSelesaiTarget;
  final bool isAlertTriggered;
  final List<int> riwayatPerpanjangan; // menit per perpanjangan
  final String? packageId;
  final String? packageName;
  final Discount? diskon;
  final List<ExtraCharge> biayaTambahan;
  final List<AddedPackage> paketTambahan; // paket ditambah saat sesi berjalan
  final String? invoiceId;

  const TableSession({
    required this.id,
    required this.tableId,
    this.tableName,
    required this.waktuMulai,
    this.waktuSelesai,
    this.durasiMenit,
    this.biaya = 0,
    required this.kasirId,
    this.kasirNama,
    required this.status,
    required this.mode,
    this.waktuSelesaiTarget,
    this.isAlertTriggered = false,
    this.riwayatPerpanjangan = const [],
    this.packageId,
    this.packageName,
    this.diskon,
    this.biayaTambahan = const [],
    this.paketTambahan = const [],
    this.invoiceId,
  });

  bool get isRunning => status == SessionStatus.berjalan;

  /// Total harga paket yang ditambahkan di tengah sesi.
  int get paketTambahanTotal => paketTambahan.fold(0, (acc, p) => acc + p.harga);

  /// Total durasi yang ditambahkan lewat perpanjangan (menit).
  int get extendedMinutes => riwayatPerpanjangan.fold(0, (a, b) => a + b);

  bool get isOverdue =>
      isRunning &&
      mode == SessionMode.durasiTetap &&
      waktuSelesaiTarget != null &&
      DateTime.now().isAfter(waktuSelesaiTarget!);

  /// Sisa waktu sampai target (bisa negatif = sudah lewat).
  Duration remainingUntilTarget(DateTime now) =>
      (waktuSelesaiTarget ?? waktuMulai).difference(now);

  TableSession copyWith({
    DateTime? waktuSelesai,
    int? durasiMenit,
    int? biaya,
    SessionStatus? status,
    bool? isAlertTriggered,
    List<int>? riwayatPerpanjangan,
    Discount? diskon,
    List<ExtraCharge>? biayaTambahan,
    List<AddedPackage>? paketTambahan,
    String? invoiceId,
  }) {
    return TableSession(
      id: id,
      tableId: tableId,
      tableName: tableName,
      waktuMulai: waktuMulai,
      waktuSelesai: waktuSelesai ?? this.waktuSelesai,
      durasiMenit: durasiMenit ?? this.durasiMenit,
      biaya: biaya ?? this.biaya,
      kasirId: kasirId,
      kasirNama: kasirNama,
      status: status ?? this.status,
      mode: mode,
      waktuSelesaiTarget: waktuSelesaiTarget,
      isAlertTriggered: isAlertTriggered ?? this.isAlertTriggered,
      riwayatPerpanjangan: riwayatPerpanjangan ?? this.riwayatPerpanjangan,
      packageId: packageId,
      packageName: packageName,
      diskon: diskon ?? this.diskon,
      biayaTambahan: biayaTambahan ?? this.biayaTambahan,
      paketTambahan: paketTambahan ?? this.paketTambahan,
      invoiceId: invoiceId ?? this.invoiceId,
    );
  }

  factory TableSession.fromFirestore(String id, Map<String, dynamic> map) {
    Timestamp? ts(dynamic v) => v is Timestamp ? v : null;
    return TableSession(
      id: id,
      tableId: map['table_id'] as String? ?? '',
      tableName: map['table_name'] as String?,
      waktuMulai: ts(map['waktu_mulai'])?.toDate() ?? DateTime.now(),
      waktuSelesai: ts(map['waktu_selesai'])?.toDate(),
      durasiMenit: (map['durasi_menit'] as num?)?.toInt(),
      biaya: (map['biaya'] as num?)?.toInt() ?? 0,
      kasirId: map['kasir_id'] as String? ?? '',
      kasirNama: map['kasir_nama'] as String?,
      status: SessionStatusX.fromStorage(map['status'] as String?),
      mode: SessionModeX.fromStorage(map['mode'] as String?),
      waktuSelesaiTarget: ts(map['waktu_selesai_target'])?.toDate(),
      isAlertTriggered: map['is_alert_triggered'] as bool? ?? false,
      riwayatPerpanjangan: (map['riwayat_perpanjangan'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [],
      packageId: map['package_id'] as String?,
      packageName: map['package_name'] as String?,
      diskon: map['diskon'] != null ? Discount.fromMap(map['diskon'] as Map<String, dynamic>) : null,
      biayaTambahan: (map['biaya_tambahan'] as List?)
              ?.map((e) => ExtraCharge.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      paketTambahan: (map['paket_tambahan'] as List?)
              ?.map((e) => AddedPackage.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      invoiceId: map['invoice_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'table_id': tableId,
        if (tableName != null) 'table_name': tableName,
        'waktu_mulai': Timestamp.fromDate(waktuMulai),
        if (waktuSelesai != null) 'waktu_selesai': Timestamp.fromDate(waktuSelesai!),
        if (durasiMenit != null) 'durasi_menit': durasiMenit,
        'biaya': biaya,
        'kasir_id': kasirId,
        if (kasirNama != null) 'kasir_nama': kasirNama,
        'status': status.storageValue,
        'mode': mode.storageValue,
        if (waktuSelesaiTarget != null)
          'waktu_selesai_target': Timestamp.fromDate(waktuSelesaiTarget!),
        'is_alert_triggered': isAlertTriggered,
        'riwayat_perpanjangan': riwayatPerpanjangan,
        if (packageId != null) 'package_id': packageId,
        if (packageName != null) 'package_name': packageName,
        if (diskon != null) 'diskon': diskon!.toMap(),
        'biaya_tambahan': biayaTambahan.map((e) => e.toMap()).toList(),
        'paket_tambahan': paketTambahan.map((e) => e.toMap()).toList(),
        if (invoiceId != null) 'invoice_id': invoiceId,
      };

  /// Durasi berjalan (untuk sesi aktif) atau durasi final.
  Duration elapsedAt(DateTime now) =>
      (status == SessionStatus.selesai ? (waktuSelesai ?? now) : now).difference(waktuMulai);
}

/// Ringkasan sesi yang sedang berjalan — dipakai di kartu dashboard.
class RunningSessionView {
  final TableSession session;
  final BillTable table;
  final Duration elapsed;
  final SessionBill bill;

  const RunningSessionView({
    required this.session,
    required this.table,
    required this.elapsed,
    required this.bill,
  });

  String get elapsedLabel => formatDuration(elapsed);
}