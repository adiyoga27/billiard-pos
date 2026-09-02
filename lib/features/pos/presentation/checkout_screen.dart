import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/billing_calculator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_providers.dart';
import '../../settings/domain/settings_models.dart';
import '../../tables/domain/package_models.dart';
import '../../tables/domain/table_models.dart';
import '../../tables/providers/tables_providers.dart';
import '../domain/product_models.dart';
import '../providers/pos_providers.dart';
import 'print_receipt_dialog.dart';

/// Halaman checkout: diskon, metode bayar, uang diterima, konfirmasi transaksi.
/// [items] = item yang dibayar (dari cart walk-in ATAU pesanan meja).
/// [sessionToFinalize] = sesi meja yang ikut difinalisasi & digabung ke struk.
class CheckoutScreen extends ConsumerStatefulWidget {
  final List<CartItem> items;
  final TableSession? sessionToFinalize;
  final String? title;
  final VoidCallback? onSuccess;

  const CheckoutScreen({
    super.key,
    required this.items,
    this.sessionToFinalize,
    this.title,
    this.onSuccess,
  });

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  PaymentMethod _method = PaymentMethod.tunai;
  bool _useDiscount = false;
  bool _discountIsPercent = true;
  bool _useMemberDiscount = true;
  final _discountCtrl = TextEditingController();
  final _discountReasonCtrl = TextEditingController();
  final _cashCtrl = TextEditingController();
  final _memberCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _discountCtrl.dispose();
    _discountReasonCtrl.dispose();
    _cashCtrl.dispose();
    _memberCtrl.dispose();
    super.dispose();
  }

  Discount? get _discount {
    if (!_useDiscount) return null;
    final value = int.tryParse(_discountCtrl.text) ?? 0;
    if (value <= 0) return null;
    return Discount(
      type: _discountIsPercent ? DiscountType.percent : DiscountType.nominal,
      value: value,
      reason: _discountReasonCtrl.text.trim().isEmpty ? null : _discountReasonCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).valueOrNull ?? const AppSettings();
    final attached = widget.sessionToFinalize;
    final sessionBill = attached != null ? _sessionBill(attached) : null;
    final sessionFee = sessionBill?.subtotal ?? 0;
    final discount = _discount;
    final memberName = _memberCtrl.text.trim();
    final memberPct =
        memberName.isNotEmpty && _useMemberDiscount ? settings.diskonMemberPersen : 0.0;
    final subtotal = widget.items.fold<int>(0, (acc, i) => acc + i.subtotal);
    final totals = calculateTransactionTotals(
      subtotal: subtotal,
      discount: discount,
      memberDiscountPercent: memberPct,
      taxPercent: settings.pajakPersen,
      serviceChargePercent: settings.serviceChargePersen,
    );
    final grandTotal = totals.total + sessionFee;
    final cashEntered = int.tryParse(_cashCtrl.text) ?? 0;
    final change = _method == PaymentMethod.tunai && cashEntered > 0 ? cashEntered - grandTotal : null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? 'Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (attached != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.billiardGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.billiardGreen.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(AppTheme.billiardIcon, color: AppTheme.billiardGreenDark),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sesi meja & pesanan dibayar SEKALI dalam struk ini.',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                // ===== DETAIL SESI MEJA =====
                if (attached != null && sessionBill != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(AppTheme.billiardIcon, color: AppTheme.billiardGreenDark, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Sesi Meja ${attached.tableName ?? ''}',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              Text(
                                formatDurationHuman(attached.elapsedAt(
                                    ref.watch(nowTickProvider).valueOrNull ?? DateTime.now())),
                                style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _BillRow(
                            label: attached.packageName != null
                                ? 'Paket ${attached.packageName}'
                                : 'Sewa meja (${formatDurationHuman(attached.elapsedAt(ref.watch(nowTickProvider).valueOrNull ?? DateTime.now()))})',
                            value: sessionBill.rentalFee,
                            bold: true,
                          ),
                          for (final g in groupAddedPackages(attached.paketTambahan))
                            _BillRow(
                              label: g.qty > 1
                                  ? 'Paket tambahan: ${g.namaPaket} × ${g.qty}'
                                  : 'Paket tambahan: ${g.namaPaket}',
                              value: g.subtotal,
                            ),
                          if (sessionBill.extraChargesTotal > 0)
                            _BillRow(
                              label: 'Biaya tambahan (${attached.biayaTambahan.length} item)',
                              value: sessionBill.extraChargesTotal,
                            ),
                          if (sessionBill.discountAmount > 0)
                            _BillRow(
                              label: 'Diskon sesi${sessionBill.discount?.reason != null ? ' (${sessionBill.discount!.reason})' : ''}',
                              value: -sessionBill.discountAmount,
                              color: AppTheme.tableFree,
                            ),
                          const Divider(height: 18),
                          _BillRow(label: 'Subtotal meja', value: sessionBill.subtotal, bold: true, big: true),
                        ],
                      ),
                    ),
                  ),
                ],
                // ===== PESANAN MAKANAN & MINUMAN =====
                if (widget.items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.restaurant_menu_rounded, color: AppTheme.billiardGreenDark, size: 20),
                              const SizedBox(width: 8),
                              Text('Pesanan Makanan & Minuman', style: Theme.of(context).textTheme.titleMedium),
                              const Spacer(),
                              Text(
                                formatRupiah(subtotal),
                                style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.billiardGreenDark),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          for (final item in widget.items)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.product.nama} × ${item.qty}',
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    formatRupiah(item.subtotal),
                                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          const Divider(height: 18),
                          _BillRow(label: 'Subtotal pesanan', value: subtotal, bold: true, big: true),
                        ],
                      ),
                    ),
                  ),
                ],
            const SizedBox(height: 12),
            Text('Metode Pembayaran', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final m in PaymentMethod.values) ...[
                  Expanded(
                    child: _MethodCard(
                      method: m,
                      selected: _method == m,
                      onTap: () => setState(() => _method = m),
                    ),
                  ),
                  if (m != PaymentMethod.values.last) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text('Member', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _memberCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Nama member (opsional)',
                hintText: 'Kosongkan untuk transaksi non-member',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            if (memberName.isNotEmpty) ...[
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Pakai diskon member (${settings.diskonMemberPersen.toStringAsFixed(0)}%)',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                value: _useMemberDiscount,
                onChanged: (v) => setState(() => _useMemberDiscount = v),
              ),
            ],
            const SizedBox(height: 14),
            Text('Diskon', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Pakai diskon', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              value: _useDiscount,
              onChanged: (v) => setState(() => _useDiscount = v),
            ),
            if (_useDiscount) ...[
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Persen')),
                  ButtonSegment(value: false, label: Text('Nominal')),
                ],
                selected: {_discountIsPercent},
                onSelectionChanged: (s) => setState(() => _discountIsPercent = s.first),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _discountCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: _discountIsPercent ? 'Diskon (%)' : 'Diskon (Rp)',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _discountReasonCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Alasan (opsional)', isDense: true),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            if (_method == PaymentMethod.tunai) ...[
              Text('Uang Diterima', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _cashCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Uang tunai (Rp)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              if (change != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    change >= 0
                        ? 'Kembalian: ${formatRupiah(change)}'
                        : 'Uang kurang: ${formatRupiah(-change)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: change >= 0 ? AppTheme.tableFree : AppTheme.tableUsed,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  if (sessionBill != null) _Row('Subtotal meja', sessionBill.subtotal),
                  _Row('Subtotal pesanan', totals.subtotal),
                  if (totals.discountAmount > 0) _Row('Diskon', -totals.discountAmount, color: AppTheme.tableFree),
                  if (totals.memberDiscountAmount > 0)
                    _Row(
                      'Diskon member ${memberPct.toStringAsFixed(0)}%${memberName.isNotEmpty ? ' ($memberName)' : ''}',
                      -totals.memberDiscountAmount,
                      color: AppTheme.tableFree,
                    ),
                  if (totals.serviceChargeAmount > 0)
                    _Row('Service charge ${settings.serviceChargePersen.toStringAsFixed(0)}%', totals.serviceChargeAmount),
                  if (totals.taxAmount > 0)
                    _Row('Pajak ${settings.pajakPersen.toStringAsFixed(0)}%', totals.taxAmount),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      Text(
                        formatRupiah(grandTotal),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.billiardGreenDark),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!, style: const TextStyle(color: AppTheme.tableUsed, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: FilledButton.icon(
            onPressed: _saving ? null : () => _submit(settings, grandTotal),
            icon: _saving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Bayar & Cetak Struk'),
          ),
        ),
      ),
    );
  }

  /// Breakdown detail biaya sesi meja (termasuk paket flat pertama &
  /// paket tambahan) — tampil lengkap di summary checkout.
  SessionBill? _sessionBill(TableSession session) {
    final now = ref.watch(nowTickProvider).valueOrNull ?? DateTime.now();
    final tables = ref.watch(tablesStreamProvider).valueOrNull ?? const <BillTable>[];
    final packages = ref.watch(packagesStreamProvider).valueOrNull ?? const <PlayPackage>[];
    final table = tables.where((t) => t.id == session.tableId).firstOrNull;
    if (table == null) return null;
    final firstPackage = session.packageId != null
        ? packages.where((p) => p.id == session.packageId).firstOrNull
        : null;
    return calculateSessionBill(
      elapsed: session.elapsedAt(now),
      ratePerHour: table.tarifPerJam,
      mode: table.metodePembulatan,
      extraCharges: session.biayaTambahan,
      addedPackagesTotal: session.paketTambahanTotal,
      discount: session.diskon,
      flatPackagePrice: firstPackage != null && firstPackage.tipe == PackageType.durasiFlat
          ? firstPackage.harga
          : null,
    );
  }

  Future<void> _submit(AppSettings settings, int grandTotal) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final cashEntered = int.tryParse(_cashCtrl.text) ?? 0;
    if (_method == PaymentMethod.tunai && cashEntered > 0 && cashEntered < grandTotal) {
      setState(() => _error = 'Uang tunai kurang dari total.');
      return;
    }

    final memberName = _memberCtrl.text.trim();
    final memberPct =
        memberName.isNotEmpty && _useMemberDiscount ? settings.diskonMemberPersen : 0.0;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final items = [
        for (final item in widget.items)
          TransactionItem(
            productId: item.product.id,
            nama: item.product.nama,
            qty: item.qty,
            hargaSatuan: item.product.harga,
          ),
      ];
      final repo = ref.read(posRepositoryProvider);
      final tx = await repo.createTransaction(
        kasir: user,
        items: items,
        discount: _discount,
        namaMember: memberName.isEmpty ? null : memberName,
        memberDiscountPercent: memberPct,
        settings: settings,
        metodeBayar: _method,
        uangDiterima: _method == PaymentMethod.tunai && cashEntered > 0 ? cashEntered : null,
        sessionToFinalize: widget.sessionToFinalize,
      );

      // Bersihkan keranjang (walk-in) yang sudah dipakai — cart meja
      // dibersihkan oleh pemanggil (halaman meja) via onSuccess.
      if (widget.sessionToFinalize == null) {
        ref.read(cartControllerProvider.notifier).clear();
      }
      widget.onSuccess?.call();

      if (!mounted) return;
      setState(() => _saving = false);
      // Tampilkan dialog hasil dengan pilihan cetak Bluetooth thermal
      // (bukan preview struk langsung), lalu tutup halaman.
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PrintReceiptDialog(
          transaction: tx,
          settings: settings,
          closeLabel: 'Transaksi Baru',
          onClose: () {
            if (mounted) context.go('/pos');
          },
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Gagal menyimpan transaksi: $e';
      });
    }
  }
}

class _MethodCard extends StatelessWidget {
  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  const _MethodCard({required this.method, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.billiardGreenDark.withValues(alpha: 0.10)
              : Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppTheme.billiardGreenDark
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(method.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(
              method.label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? AppTheme.billiardGreenDark : AppTheme.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final int value;
  final Color? color;

  const _Row(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13.5,
                  color: color ?? Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(
            '${value < 0 ? '-' : ''}${formatRupiah(value.abs())}',
            style: TextStyle(fontWeight: FontWeight.w700, color: color ?? AppTheme.ink),
          ),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final int value;
  final bool bold;
  final bool big;
  final Color? color;

  const _BillRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.big = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: big ? 16 : 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ),
          Text(
            '${value < 0 ? '-' : ''}${formatRupiah(value.abs())}',
            style: TextStyle(
              fontSize: big ? 18 : 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? AppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}