/// Paket main billiard: durasi flat (harga fixed) atau tarif khusus per jam.
library;

enum PackageType { durasiFlat, tarifKhusus }

extension PackageTypeX on PackageType {
  String get label => this == PackageType.durasiFlat ? 'Durasi flat' : 'Tarif khusus / jam';

  String get storageValue => this == PackageType.durasiFlat ? 'durasi_flat' : 'tarif_khusus';

  static PackageType fromStorage(String? v) => v == 'tarif_khusus' ? PackageType.tarifKhusus : PackageType.durasiFlat;
}

class PlayPackage {
  final String id;
  final String namaPaket;
  final PackageType tipe;
  final int? durasiMenit; // wajib jika durasi_flat
  final int harga; // harga flat (durasi_flat) atau tarif per jam (tarif_khusus)
  final List<int> hariAktif; // 1=Senin .. 7=Minggu, kosong = semua hari
  final int? jamMulaiBerlaku; // 0-23, optional
  final int? jamSelesaiBerlaku;
  final List<String> berlakuUntukMeja; // kosong = semua meja
  final bool isActive;

  const PlayPackage({
    required this.id,
    required this.namaPaket,
    required this.tipe,
    this.durasiMenit,
    required this.harga,
    this.hariAktif = const [],
    this.jamMulaiBerlaku,
    this.jamSelesaiBerlaku,
    this.berlakuUntukMeja = const [],
    this.isActive = true,
  });

  /// Apakah paket berlaku untuk kombinasi hari & jam & meja saat ini.
  bool appliesAt(DateTime now, String tableId) {
    if (!isActive) return false;
    if (berlakuUntukMeja.isNotEmpty && !berlakuUntukMeja.contains(tableId)) return false;
    if (hariAktif.isNotEmpty && !hariAktif.contains(now.weekday)) return false;
    if (jamMulaiBerlaku != null && now.hour < jamMulaiBerlaku!) return false;
    if (jamSelesaiBerlaku != null && now.hour >= jamSelesaiBerlaku!) return false;
    return true;
  }

  String get hariLabel => hariAktif.isEmpty
      ? 'Semua hari'
      : hariAktif.map((d) => _hariNames[d]!).join(', ');

  String get jamLabel {
    if (jamMulaiBerlaku == null && jamSelesaiBerlaku == null) return 'Semua jam';
    final s = jamMulaiBerlaku?.toString().padLeft(2, '0') ?? '00';
    final e = jamSelesaiBerlaku?.toString().padLeft(2, '0') ?? '23';
    return '$s:00 – $e:00';
  }

  factory PlayPackage.fromFirestore(String id, Map<String, dynamic> map) => PlayPackage(
        id: id,
        namaPaket: map['nama_paket'] as String? ?? '',
        tipe: PackageTypeX.fromStorage(map['tipe'] as String?),
        durasiMenit: (map['durasi_menit'] as num?)?.toInt(),
        harga: (map['harga'] as num?)?.toInt() ?? 0,
        hariAktif: (map['hari_aktif'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [],
        jamMulaiBerlaku: (map['jam_mulai_berlaku'] as num?)?.toInt(),
        jamSelesaiBerlaku: (map['jam_selesai_berlaku'] as num?)?.toInt(),
        berlakuUntukMeja:
            (map['berlaku_untuk_meja'] as List?)?.map((e) => e as String).toList() ?? const [],
        isActive: map['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'nama_paket': namaPaket,
        'tipe': tipe.storageValue,
        if (durasiMenit != null) 'durasi_menit': durasiMenit,
        'harga': harga,
        'hari_aktif': hariAktif,
        if (jamMulaiBerlaku != null) 'jam_mulai_berlaku': jamMulaiBerlaku,
        if (jamSelesaiBerlaku != null) 'jam_selesai_berlaku': jamSelesaiBerlaku,
        'berlaku_untuk_meja': berlakuUntukMeja,
        'is_active': isActive,
      };

  static const _hariNames = {
    1: 'Senin',
    2: 'Selasa',
    3: 'Rabu',
    4: 'Kamis',
    5: 'Jumat',
    6: 'Sabtu',
    7: 'Minggu',
  };
}