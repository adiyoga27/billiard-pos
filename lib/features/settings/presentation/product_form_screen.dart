import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/form_page.dart';
import '../../pos/domain/product_models.dart';
import '../../pos/providers/pos_providers.dart';

/// Halaman tambah/edit produk (bukan modal — responsive penuh).
class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  late final TextEditingController _namaCtrl =
      TextEditingController(text: widget.product?.nama ?? '');
  late final TextEditingController _hargaCtrl =
      TextEditingController(text: widget.product != null ? '${widget.product!.harga}' : '');
  late final TextEditingController _stokCtrl =
      TextEditingController(text: widget.product != null ? '${widget.product!.stok}' : '');
  String? _kategoriId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _kategoriId = widget.product?.kategoriId;
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _hargaCtrl.dispose();
    _stokCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nama = _namaCtrl.text.trim();
    final harga = int.tryParse(_hargaCtrl.text) ?? 0;
    final stok = int.tryParse(_stokCtrl.text) ?? 0;
    if (nama.isEmpty || harga <= 0 || _kategoriId == null) {
      setState(() => _error = 'Nama, kategori, dan harga wajib diisi.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(posRepositoryProvider).saveProduct(
            id: widget.product?.id,
            nama: nama,
            kategoriId: _kategoriId!,
            harga: harga,
            stok: stok,
          );
      if (mounted) context.pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Gagal menyimpan: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesStreamProvider).valueOrNull ?? const <Category>[];
    if (_kategoriId == null && categories.isNotEmpty) {
      _kategoriId = categories.first.id;
    }

    return FormPage(
      title: widget.product == null ? 'Tambah Produk' : 'Edit Produk',
      saving: _saving,
      onSave: categories.isEmpty ? null : _save,
      hint: categories.isEmpty ? 'Buat kategori dulu di menu Kategori.' : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _namaCtrl,
            decoration: const InputDecoration(
              labelText: 'Nama produk',
              prefixIcon: Icon(Icons.fastfood_rounded),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String?>(
            initialValue: _kategoriId,
            decoration: const InputDecoration(
              labelText: 'Kategori',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: [
              for (final c in categories)
                DropdownMenuItem(value: c.id, child: Text(c.nama)),
            ],
            onChanged: (v) => setState(() => _kategoriId = v),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hargaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Harga (Rp)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _stokCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Stok',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: AppTheme.tableUsed, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}