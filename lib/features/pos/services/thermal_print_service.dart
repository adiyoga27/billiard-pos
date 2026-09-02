import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// Perangkat printer thermal Bluetooth yang sudah dipasangkan (paired).
class ThermalPrinterDevice {
  final String name;
  final String mac;

  const ThermalPrinterDevice({required this.name, required this.mac});
}

/// Layanan cetak struk ke printer thermal via Bluetooth.
///
/// Semua kegagalan ditelan menjadi nilai balik `false` / list kosong
/// supaya UI tetap jalan di perangkat/web tanpa Bluetooth.
class ThermalPrintService {
  const ThermalPrintService();

  /// Bluetooth printing tersedia di Android, iOS, macOS & Windows.
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  /// Daftar perangkat Bluetooth yang sudah pernah dipasangkan.
  Future<List<ThermalPrinterDevice>> pairedDevices() async {
    try {
      final raw = await PrintBluetoothThermal.pairedBluetooths
          .timeout(const Duration(seconds: 3));
      return [
        for (final d in raw)
          ThermalPrinterDevice(name: d.name, mac: d.macAdress),
      ];
    } catch (_) {
      return const [];
    }
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
