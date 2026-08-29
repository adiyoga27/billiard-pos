import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/domain/billing_calculator.dart';
import '../../../shared/widgets/responsive_scaffold.dart';
import '../../tables/domain/table_models.dart';
import '../../tables/providers/tables_providers.dart';

/// Manajemen meja: tambah, edit tarif, pembulatan, hapus.
class TableManagementScreen extends ConsumerWidget {
  const TableManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tablesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manajemen Meja')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/settings/table-form'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Meja'),
      ),
      body: tables.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (list) => CenteredContent(
          maxWidth: 860,
          child: list.isEmpty
              ? const EmptyState(
                  icon: AppTheme.billiardIcon,
                  message: 'Belum ada meja',
                  hint: 'Tambahkan meja pertama untuk mulai.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final t = list[i];
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _statusColor(t.status).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(AppTheme.billiardIcon, color: _statusColor(t.status)),
                        ),
                        title: Text(t.namaMeja, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          '${formatRupiah(t.tarifPerJam)}/jam • ${t.metodePembulatan.label} • ${t.status.label}',
                        ),
                        onTap: () => context.push('/settings/table-form', extra: t),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') context.push('/settings/table-form', extra: t);
                            if (v == 'delete') _deleteTable(context, ref, t);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Hapus')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Color _statusColor(TableStatus status) => switch (status) {
        TableStatus.kosong => AppTheme.tableFree,
        TableStatus.terpakai => AppTheme.tableUsed,
        TableStatus.reserved => AppTheme.tableReserved,
      };

  void _deleteTable(BuildContext context, WidgetRef ref, BillTable table) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Hapus ${table.namaMeja}?'),
        content: const Text('Aksi ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.tableUsed),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(tablesRepositoryProvider).deleteTable(table.id);
    }
  }
}