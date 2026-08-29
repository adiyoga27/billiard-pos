import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/responsive_scaffold.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/providers/auth_providers.dart';

/// Manajemen staff: buat akun kasir, ubah role, hapus.
class StaffManagementScreen extends ConsumerWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffStreamProvider);
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Staff & Role')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/settings/staff-form'),
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Tambah Kasir'),
      ),
      body: staff.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (list) => CenteredContent(
          maxWidth: 860,
          child: list.isEmpty
              ? const EmptyState(
                  icon: Icons.group_outlined,
                  message: 'Belum ada staff',
                  hint: 'Buat akun kasir untuk tim Anda.',
                )
              : ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final s = list[i];
            final isMe = s.uid == me?.uid;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: (s.isAdmin ? AppTheme.tableReserved : AppTheme.billiardGreen)
                      .withValues(alpha: 0.15),
                  child: Text(
                    s.nama.isNotEmpty ? s.nama[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: s.isAdmin ? AppTheme.tableReserved : AppTheme.billiardGreenDark,
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(s.nama, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    if (isMe)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text('(Anda)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                  ],
                ),
                subtitle: Text(s.email, style: const TextStyle(fontSize: 12.5)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (s.isAdmin ? AppTheme.tableReserved : AppTheme.billiardGreen)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        s.role.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: s.isAdmin ? AppTheme.tableReserved : AppTheme.billiardGreenDark,
                        ),
                      ),
                    ),
                    if (!isMe)
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'role') _toggleRole(context, ref, s);
                          if (v == 'delete') _delete(context, ref, s);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'role',
                            child: Text(s.isAdmin ? 'Jadikan Kasir' : 'Jadikan Admin'),
                          ),
                          const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                        ],
                      ),
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

Future<void> _toggleRole(BuildContext context, WidgetRef ref, AppUser s) async {
    await ref.read(authRepositoryProvider).setRole(
          s.uid,
          s.isAdmin ? UserRole.kasir : UserRole.admin,
        );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, AppUser s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Hapus ${s.nama}?'),
        content: const Text('Akun tidak bisa login lagi. (Dihapus dari koleksi users)'),
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
      await ref.read(authRepositoryProvider).deleteStaff(s.uid);
    }
  }
}