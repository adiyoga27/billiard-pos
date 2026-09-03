import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Perangkat printer thermal Bluetooth yang sudah dipasangkan (paired).
class ThermalPrinterDevice {
  final String name;
  final String mac;

  const ThermalPrinterDevice({required this.name, required this.mac});
}

/// Hasil permintaan izin Bluetooth.
enum BluetoothPermissionResult { granted, denied, permanentlyDenied }

/// Layanan cetak struk ke printer thermal via Bluetooth.
///
/// Semua kegagalan ditelan menjadi nilai balik `false` / list kosong
/// supaya UI tetap jalan di perangkat/web tanpa Bluetooth.
class ThermalPrintService {
  const ThermalPrintService();

  /// `flutter test` menetapkan FLUTTER_TEST=true saat kompilasi — dipakai
  /// untuk mempersingkat timeout di test (fake clock) tapi tetap memberi
  /// user waktu menjawab dialog izin sistem di perangkat asli.
  static const bool _isTest = bool.fromEnvironment('FLUTTER_TEST');

  static const _printerKeys = [
    'printer', 'print', 'thermal', 'receipt', 'pos', 'eppos', 'hprt',
    'xprinter', 'gprinter', 'niimbot', 'rongta', 'sunmi', 'inner', 'peri',
    'impresora', 'ticketera', 'label', 'mpt', 'sku', 'p58', 'p80', '58mm',
    '80mm', '58 mm', '80 mm', 'tm-t', 'sp700', 'epson', 'doth',
  ];

  static const _nonPrinterKeys = [
    'headset', 'headphone', 'earphone', 'earbud', 'airpod', 'buds', 'tws',
    'speaker', 'soundbar', 'audio', 'music', 'jbl', 'sony', 'bose',
    'keyboard', 'mouse', 'watch', 'band', 'phone', 'iphone', 'samsung',
    'galaxy', 'xiaomi', 'redmi', 'oppo', 'vivo', 'realme', 'honor',
    'laptop', 'tablet', 'ipad', 'macbook', 'thinkpad', 'tv', 'remote',
    'controller', 'gamepad', 'joypad',
  ];

  /// Nama perangkat yang ciri-cirinya BUKAN printer (headset, HP, dsb).
  static bool isNonPrinterDevice(String name) {
    final n = name.toLowerCase();
    return _nonPrinterKeys.any(n.contains);
  }

  /// Nama perangkat yang ciri-cirinya printer thermal.
  static bool looksLikePrinter(String name) {
    final n = name.toLowerCase();
    return _printerKeys.any(n.contains);
  }

  /// Bluetooth printing tersedia di Android, iOS, macOS & Windows.
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  /// Android 12+ (API 31+) butuh izin runtime "Perangkat di sekitar"
  /// (BLUETOOTH_CONNECT / BLUETOOTH_SCAN) — plugin hanya mengecek, tidak
  /// pernah meminta. Method ini MEMINTA izin ke user.
  Future<BluetoothPermissionResult> ensureBluetoothPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return BluetoothPermissionResult.granted;
    }
    // Di perangkat asli beri waktu cukup untuk menjawab dialog izin sistem.
    const timeout = _isTest ? Duration(seconds: 2) : Duration(seconds: 60);
    const deniedStatus = PermissionStatus.denied;
    try {
      var connect = await Permission.bluetoothConnect.status
          .timeout(const Duration(seconds: 3), onTimeout: () => deniedStatus);
      if (!connect.isGranted) {
        connect = await Permission.bluetoothConnect
            .request()
            .timeout(timeout, onTimeout: () => deniedStatus);
      }
      if (!connect.isGranted) {
        return connect.isPermanentlyDenied
            ? BluetoothPermissionResult.permanentlyDenied
            : BluetoothPermissionResult.denied;
      }

      var scan = await Permission.bluetoothScan.status
          .timeout(const Duration(seconds: 3), onTimeout: () => deniedStatus);
      if (!scan.isGranted) {
        scan = await Permission.bluetoothScan
            .request()
            .timeout(timeout, onTimeout: () => deniedStatus);
      }
      if (!scan.isGranted) {
        return scan.isPermanentlyDenied
            ? BluetoothPermissionResult.permanentlyDenied
            : BluetoothPermissionResult.denied;
      }
      return BluetoothPermissionResult.granted;
    } catch (_) {
      return BluetoothPermissionResult.denied;
    }
  }

  /// Buka halaman pengaturan aplikasi (untuk izin yang ditolak permanen).
  /// `true` jika pengaturan berhasil dibuka.
  Future<bool> openPermissionSettings() async {
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Daftar perangkat Bluetooth yang sudah pernah dipasangkan — hanya yang
  /// terlihat seperti printer thermal (headset, HP, dsb. disembunyikan).
  Future<List<ThermalPrinterDevice>> pairedDevices() async {
    try {
      final raw = await PrintBluetoothThermal.pairedBluetooths
          .timeout(const Duration(seconds: 3));
      return [
        for (final d in raw)
          if (!isNonPrinterDevice(d.name)) ThermalPrinterDevice(name: d.name, mac: d.macAdress),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Printer terakhir yang dipakai (tersimpan lokal per perangkat).
  Future<ThermalPrinterDevice?> savedPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      final mac = prefs.getString('last_printer_mac');
      final name = prefs.getString('last_printer_name');
      if (mac == null || mac.isEmpty) return null;
      return ThermalPrinterDevice(name: name ?? 'Printer', mac: mac);
    } catch (_) {
      return null;
    }
  }

  /// Simpan printer pilihan kasir (dipakai otomatis di cetak berikutnya).
  Future<void> savePrinter(ThermalPrinterDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      await prefs.setString('last_printer_mac', device.mac);
      await prefs.setString('last_printer_name', device.name);
    } catch (_) {}
  }

  /// Sambungkan ke printer [mac] lalu kirim [bytes]. `true` jika sukses.
  Future<bool> printTo({required String mac, required List<int> bytes}) async {
    try {
      final granted = await PrintBluetoothThermal.isPermissionBluetoothGranted
          .timeout(const Duration(seconds: 5));
      if (!granted) return false;
      final connected = await PrintBluetoothThermal.connect(macPrinterAddress: mac)
          .timeout(const Duration(seconds: 10));
      if (!connected) return false;
      final sent = await PrintBluetoothThermal.writeBytes(bytes)
          .timeout(const Duration(seconds: 15));
      return sent;
    } catch (_) {
      return false;
    }
  }
}
