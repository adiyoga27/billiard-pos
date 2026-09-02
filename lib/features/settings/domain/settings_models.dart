import '../../../core/domain/billing_calculator.dart';

/// Pengaturan global aplikasi (doc `settings/global`).
class AppSettings {
  final String namaToko;
  final String alamat;
  final String noTelp;
  final RoundingMode pembulatan;
  final int ambangPeringatanMenit; // default 10 menit sebelum habis
  final double pajakPersen;
  final double serviceChargePersen;
  final double diskonMemberPersen; // diskon otomatis saat nama member diisi

  const AppSettings({
    this.namaToko = 'Yes Billiard',
    this.alamat = '',
    this.noTelp = '',
    this.pembulatan = RoundingMode.per15Minutes,
    this.ambangPeringatanMenit = 10,
    this.pajakPersen = 0,
    this.serviceChargePersen = 0,
    this.diskonMemberPersen = 5,
  });

  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
        namaToko: map['nama_toko'] as String? ?? 'Yes Billiard',
        alamat: map['alamat'] as String? ?? '',
        noTelp: map['no_telp'] as String? ?? '',
        pembulatan: RoundingModeX.fromStorage(map['pembulatan'] as String?),
        ambangPeringatanMenit: (map['ambang_peringatan_menit'] as num?)?.toInt() ?? 10,
        pajakPersen: (map['pajak_persen'] as num?)?.toDouble() ?? 0,
        serviceChargePersen: (map['service_charge_persen'] as num?)?.toDouble() ?? 0,
        diskonMemberPersen: (map['diskon_member_persen'] as num?)?.toDouble() ?? 5,
      );

  Map<String, dynamic> toMap() => {
        'nama_toko': namaToko,
        'alamat': alamat,
        'no_telp': noTelp,
        'pembulatan': pembulatan.storageValue,
        'ambang_peringatan_menit': ambangPeringatanMenit,
        'pajak_persen': pajakPersen,
        'service_charge_persen': serviceChargePersen,
        'diskon_member_persen': diskonMemberPersen,
      };
}