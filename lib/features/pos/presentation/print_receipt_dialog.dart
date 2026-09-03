import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../settings/domain/settings_models.dart';
import '../domain/product_models.dart';
import '../services/thermal_print_service.dart';
import 'receipt_builder.dart';

/// Dialog hasil transaksi: pilihan utama adalah CETAK via Bluetooth thermal.
/// Preview struk & salin tetap tersedia sebagai cadangan (mis. di Windows/web).
class PrintReceiptDialog extends ConsumerStatefulWidget {
  final Transaction transaction;
  final AppSettings settings;
  final String title;
  final String closeLabel;
  final VoidCallback? onClose;

  const PrintReceiptDialog({
    super.key,
    required this.transaction,
    required this.settings,
    this.title = 'Transaksi Berhasil',
    this.closeLabel = 'Tutup',
    this.onClose,
  });

  @override
  ConsumerState<PrintReceiptDialog> createState() => _PrintReceiptDialogState();
}

class _PrintReceiptDialogState extends ConsumerState<PrintReceiptDialog>
    with WidgetsBindingObserver {
  static const _service = ThermalPrintService();

  bool _loading = true;
  bool _requestingPerm = false;
  bool _permDenied = false;
  bool _permPermanent = false;
  String? _error;
  String? _printingMac;
  ThermalPrinterDevice? _autoPrinting;
  ThermalPrinterDevice? _savedPrinter;
  List<ThermalPrinterDevice> _devices = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Ketika user kembali dari halaman pengaturan Android, cek ulang izin
  /// supaya daftar printer langsung dimuat tanpa tutup-buka dialog.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && (_permDenied || _permPermanent)) {
      _init();
    }
  }

  /// Minta izin Bluetooth (Android 12+), lalu muat daftar printer.
  Future<void> _init() async {
    setState(() {
      _loading = true;
      _requestingPerm = false;
      _permDenied = false;
      _permPermanent = false;
      _error = null;
      _autoPrinting = null;
    });
    if (_service.isSupported) {
      setState(() => _requestingPerm = true);
      final result = await _service.ensureBluetoothPermission();
      if (!mounted) return;
      if (result != BluetoothPermissionResult.granted) {
        setState(() {
          _loading = false;
          _requestingPerm = false;
          _permDenied = true;
          _permPermanent =
              result == BluetoothPermissionResult.permanentlyDenied;
        });
        return;
      }
    }
    await _loadDevices();
  }

  Future<void> _openSettings() async {
    final ok = await _service.openPermissionSettings();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Tidak bisa membuka pengaturan. Buka manual: Setelan aplikasi → Izin → Perangkat di sekitar.'),
        ),
      );
    }
  }

  Future<void> _loadDevices() async {
    final devices = _service.isSupported ? await _service.pairedDevices() : const <ThermalPrinterDevice>[];
    if (!mounted) return;

    final saved = await _service.savedPrinter();
    if (!mounted) return;

    setState(() {
      _devices = devices;
      _savedPrinter = saved;
      _loading = false;
      _requestingPerm = false;
    });

    // Printer terakhir masih terpasang → langsung cetak, tidak perlu pilih lagi.
    final savedStillPaired = saved != null &&
        devices.any((d) => d.mac.toLowerCase() == saved.mac.toLowerCase());
    if (savedStillPaired) {
      await _print(saved, auto: true);
    }
  }

  Future<void> _print(ThermalPrinterDevice device, {bool auto = false}) async {
    setState(() {
      _printingMac = device.mac;
      _autoPrinting = auto ? device : null;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final bytes = await const ReceiptBuilder().buildEscBytes(
        transaction: widget.transaction,
        settings: widget.settings,
      );
      final ok = await _service.printTo(mac: device.mac, bytes: bytes);
      if (!mounted) return;
      if (ok) {
        await _service.savePrinter(device);
        messenger.showSnackBar(SnackBar(content: Text('Struk terkirim ke ${device.name}')));
        navigator.pop();
        return;
      }
      setState(() {
        _printingMac = null;
        _autoPrinting = null;
        _error = auto
            ? 'Gagal mencetak ke ${device.name}. Pilih printer lain di bawah.'
            : 'Gagal mencetak ke ${device.name}. Periksa koneksi printer.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _printingMac = null;
        _autoPrinting = null;
        _error = 'Gagal mencetak: $e';
      });
    }
  }

  void _showPreview() {
    final text = const ReceiptBuilder().buildText(
      transaction: widget.transaction,
      settings: widget.settings,
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Struk'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, height: 1.35),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _copy() async {
    final text = const ReceiptBuilder().buildText(
      transaction: widget.transaction,
      settings: widget.settings,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Struk disalin ke clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final paperMm = widget.settings.kertasMm;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.title == 'Transaksi Berhasil'
                ? Icons.check_circle_rounded
                : Icons.print_rounded,
            color: AppTheme.billiardGreen,
            size: 26,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.title,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${tx.nomor} • ${tx.metodeBayar.label}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                'Total ${formatRupiah(tx.total)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.billiardGreenDark,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.print_rounded, size: 20, color: AppTheme.billiardGreenDark),
                  const SizedBox(width: 8),
                  Text('Cetak Struk', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.billiardGreen.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppTheme.billiardGreen.withValues(alpha: 0.30)),
                    ),
                    child: Text(
                      'Kertas $paperMm mm',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.billiardGreenDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_permDenied)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.tableReserved.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.tableReserved.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.bluetooth_disabled_rounded,
                          size: 32, color: AppTheme.tableReserved),
                      const SizedBox(height: 8),
                      Text(
                        _permPermanent ? 'Izin Bluetooth ditolak permanen' : 'Izin Bluetooth belum diberikan',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _permPermanent
                            ? 'Aktifkan izin "Perangkat di sekitar" di pengaturan aplikasi, lalu kembali ke sini.'
                            : 'Android butuh izin "Perangkat di sekitar" untuk mencetak struk.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: _permPermanent
                            ? [
                                FilledButton.tonalIcon(
                                  onPressed: _openSettings,
                                  icon: const Icon(Icons.settings_rounded, size: 18),
                                  label: const Text('Buka Pengaturan'),
                                ),
                                OutlinedButton(
                                  onPressed: _init,
                                  child: const Text('Coba Lagi'),
                                ),
                              ]
                            : [
                                FilledButton.tonalIcon(
                                  onPressed: _init,
                                  icon: const Icon(Icons.verified_user_outlined, size: 18),
                                  label: const Text('Aktifkan Izin'),
                                ),
                                OutlinedButton(
                                  onPressed: _openSettings,
                                  child: const Text('Buka Pengaturan'),
                                ),
                              ],
                      ),
                    ],
                  ),
                )
              else if (_loading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(width: 10),
                      Text(_requestingPerm ? 'Meminta izin Bluetooth...' : 'Mencari printer...'),
                    ],
                  ),
                )
              else if (!_service.isSupported)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.tableReserved.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.tableReserved.withValues(alpha: 0.35)),
                  ),
                  child: const Text(
                    'Cetak Bluetooth hanya tersedia di perangkat Android/iOS. '
                    'Gunakan "Lihat Struk" untuk menampilkan atau menyimpan struk.',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                )
              else if (_devices.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.bluetooth_searching_rounded,
                          size: 32, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      const Text(
                        'Tidak ada printer terpasang',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _savedPrinter != null
                            ? 'Printer "${_savedPrinter!.name}" tidak terdeteksi. Nyalakan printer atau pasangkan ulang, lalu pindai.'
                            : 'Nyalakan Bluetooth & pasangkan printer thermal di pengaturan perangkat, lalu pindai ulang.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _loadDevices,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Pindai Ulang'),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    if (_autoPrinting != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.billiardGreen.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.billiardGreen.withValues(alpha: 0.30)),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Mencetak ke ${_autoPrinting!.name}...',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _printingMac = null;
                                _autoPrinting = null;
                              }),
                              child: const Text('Pilih lain'),
                            ),
                          ],
                        ),
                      ),
                    for (final d in _devices)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppTheme.billiardGreen.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.print_rounded,
                                size: 20, color: AppTheme.billiardGreenDark),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  d.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                              ),
                              if (_savedPrinter != null &&
                                  d.mac.toLowerCase() == _savedPrinter!.mac.toLowerCase())
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.billiardGreen.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Terakhir dipakai',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.billiardGreenDark,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(d.mac, style: const TextStyle(fontSize: 11)),
                          trailing: _printingMac == d.mac
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                )
                              : FilledButton.tonalIcon(
                                  onPressed: () => _print(d),
                                  icon: const Icon(Icons.print_rounded, size: 18),
                                  label: const Text('Cetak'),
                                ),
                        ),
                      ),
                  ],
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.tableUsed, fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showPreview,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Lihat Struk (preview)'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _copy,
          child: const Text('Salin Struk'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onClose?.call();
          },
          child: Text(widget.closeLabel),
        ),
      ],
    );
  }
}
