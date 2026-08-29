import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_providers.dart';
import '../../../shared/widgets/responsive_scaffold.dart';
import '../../tables/providers/tables_providers.dart';
import '../domain/settings_models.dart';

/// Modul Pengaturan (admin only): tarif meja, pembulatan, paket, pajak,
/// staff, seed data demo.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null || !user.isAdmin) {
      return const Scaffold(body: Center(child: Text('Khusus Admin')));
    }

    final settings = ref.watch(settingsProvider).valueOrNull ?? const AppSettings();

    return ResponsiveScaffold(
      currentLocation: '/settings',
      child: Column(
        children: [
          const PageHeader(title: 'Pengaturan', subtitle: 'Konfigurasi toko & bisnis'),
          Expanded(
            child: CenteredContent(
              maxWidth: 860,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                _SectionCard(
                  icon: Icons.storefront_rounded,
                  color: AppTheme.billiardGreen,
                  title: 'Profil Toko & Tarif',
                  subtitle: 'Nama toko, pembulatan waktu, ambang peringatan, pajak & service charge',
                  onTap: () => context.push('/settings/settings-form', extra: settings),
                ),
                _SectionCard(
                  icon: AppTheme.billiardIcon,
                  color: AppTheme.tableUsed,
                  title: 'Manajemen Meja',
                  subtitle: 'Tambah/edit tarif per jam & pembulatan tiap meja',
                  onTap: () => context.push('/settings/tables'),
                ),
                _SectionCard(
                  icon: Icons.card_giftcard_rounded,
                  color: AppTheme.tableReserved,
                  title: 'Paket Main Billiard',
                  subtitle: 'Paket durasi flat & tarif khusus, aktifkan/nonaktifkan',
                  onTap: () => context.push('/settings/packages'),
                ),
                _SectionCard(
                  icon: Icons.fastfood_rounded,
                  color: const Color(0xFF7C3AED),
                  title: 'Produk & Kategori',
                  subtitle: 'Katalog makanan/minuman/snack untuk POS',
                  onTap: () => context.push('/settings/products'),
                ),
                _SectionCard(
                  icon: Icons.group_outlined,
                  color: const Color(0xFF0EA5E9),
                  title: 'Staff & Role',
                  subtitle: 'Buat akun kasir, ubah role admin/kasir',
                  onTap: () => context.push('/settings/staff'),
                ),
                _SectionCard(
                  icon: Icons.auto_awesome_rounded,
                  color: const Color(0xFFF97316),
                  title: 'Seed Data Demo',
                  subtitle: 'Isi otomatis: 8 meja, 12 produk, 2 paket (idempotent)',
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Seed data demo?'),
                        content: const Text(
                          'Akan membuat 8 meja, 12 produk, 3 kategori, dan 2 paket contoh. Data yang sudah ada tidak dihapus.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(false),
                            child: const Text('Batal'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(dialogContext).pop(true),
                            child: const Text('Seed Sekarang'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref
                          .read(tablesRepositoryProvider)
                          .seedDemoData(settings: settings);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Data demo berhasil dibuat')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }

}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SectionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12.5)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}