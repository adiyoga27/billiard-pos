import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/app_user.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../core/theme/app_theme.dart';

/// Shell responsif dengan 3 breakpoint:
/// - < 900px  : bottom navigation (HP / tablet portrait)
/// - 900-1199 : compact rail (tablet landscape / jendela sempit desktop)
/// - >= 1200  : sidebar penuh (desktop)
/// Navigasi dipisah per grup: MEJA & SESI terpisah dari KASIR (POS walk-in),
/// supaya alur meja dan counter sale tidak tercampur.
class ResponsiveScaffold extends ConsumerWidget {
  final Widget child;
  final String currentLocation;

  const ResponsiveScaffold({
    super.key,
    required this.child,
    required this.currentLocation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isSidebar = width >= AppTheme.kRailMaxWidth;
    final isRail = width >= AppTheme.kMobileMaxWidth;

    final destinations = <_NavDest>[
      // Grup MEJA & SESI
      _NavDest(
        route: '/',
        label: 'Meja & Sesi',
        icon: AppTheme.billiardIcon,
        selectedIcon: AppTheme.billiardIcon,
        section: 'MEJA & SESI',
      ),
      // Grup KASIR (transaksi tanpa meja)
      _NavDest(
        route: '/pos',
        label: 'Kasir Walk-in',
        icon: Icons.point_of_sale_rounded,
        selectedIcon: Icons.point_of_sale_rounded,
        section: 'KASIR',
      ),
      _NavDest(
        route: '/reports',
        label: 'Laporan',
        icon: Icons.bar_chart_rounded,
        selectedIcon: Icons.bar_chart_rounded,
        section: 'LAPORAN',
      ),
      if (user?.isAdmin ?? false)
        _NavDest(
          route: '/settings',
          label: 'Pengaturan',
          icon: Icons.settings_rounded,
          selectedIcon: Icons.settings_rounded,
          section: 'ADMIN',
        ),
    ];

    int selectedIndex() {
      for (var i = 0; i < destinations.length; i++) {
        final d = destinations[i];
        if (currentLocation == d.route || currentLocation.startsWith('${d.route}/')) return i;
      }
      return 0;
    }

    if (isSidebar) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(user: user, destinations: destinations, selectedIndex: selectedIndex()),
            Expanded(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: child,
              ),
            ),
          ],
        ),
      );
    }

    if (isRail) {
      return Scaffold(
        body: Row(
          children: [
            _NavRail(user: user, destinations: destinations, selectedIndex: selectedIndex()),
            Expanded(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: child,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex(),
        onDestinationSelected: (i) => context.go(destinations[i].route),
        destinations: [
          for (final d in destinations)
            NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
        ],
      ),
    );
  }
}

class _NavDest {
  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String? section;

  const _NavDest({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.section,
  });
}

/// Logo + nama aplikasi (dipakai sidebar & rail).
class _BrandMark extends StatelessWidget {
  final bool compact;

  const _BrandMark({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mark = Container(
      width: compact ? 40 : 42,
      height: compact ? 40 : 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.billiardGreen, AppTheme.billiardGreenDark],
        ),
        borderRadius: BorderRadius.circular(compact ? 12 : 13),
        boxShadow: [
          BoxShadow(
            color: AppTheme.billiardGreen.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(AppTheme.billiardIcon, color: Colors.white, size: 24),
    );

    if (compact) return mark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        mark,
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yes Billiard', style: theme.textTheme.titleMedium),
            Text('POS System', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
      ],
    );
  }
}

class _LogoutButton extends ConsumerWidget {
  final bool showLabel;

  const _LogoutButton({this.showLabel = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: 'Keluar',
      child: InkWell(
        onTap: () async => ref.read(authRepositoryProvider).logout(),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.logout_rounded, size: 20, color: AppTheme.tableUsed),
              if (showLabel) ...[
                const SizedBox(width: 8),
                Text(
                  'Keluar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.tableUsed,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  final AppUser? user;
  final List<_NavDest> destinations;
  final int selectedIndex;

  const _Sidebar({
    required this.user,
    required this.destinations,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final u = user; // lokal supaya type promotion bekerja di collection literal
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: 256,
        child: Column(
          children: [
            const SizedBox(height: 20),
            const _BrandMark(),
            const SizedBox(height: 20),
            const Divider(),
            // Navigasi per grup (Meja terpisah dari Kasir)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  for (var i = 0; i < destinations.length; i++) ...[
                    if (i == 0 || destinations[i].section != destinations[i - 1].section)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                        child: Text(
                          destinations[i].section ?? '',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: _NavItem(
                        label: destinations[i].label,
                        icon: i == selectedIndex ? destinations[i].selectedIcon : destinations[i].icon,
                        selected: i == selectedIndex,
                        onTap: () => context.go(destinations[i].route),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(),
            if (u != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.billiardGreen.withValues(alpha: 0.15),
                        child: Text(
                          u.nama.isNotEmpty ? u.nama[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.billiardGreenDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u.nama,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              u.role.label,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(alignment: Alignment.centerLeft, child: _LogoutButton()),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.billiardGreen.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? AppTheme.billiardGreenDark : Colors.grey.shade500,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13.5,
                  color: selected ? AppTheme.billiardGreenDark : Colors.grey.shade700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: selected ? 1 : 0,
              child: Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppTheme.billiardGreen,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavRail extends ConsumerWidget {
  final AppUser? user;
  final List<_NavDest> destinations;
  final int selectedIndex;

  const _NavRail({
    required this.user,
    required this.destinations,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = user;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: SizedBox(
          width: 88,
          child: Column(
            children: [
              const SizedBox(height: 16),
              const _BrandMark(compact: true),
              const SizedBox(height: 8),
              Expanded(
                child: NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (i) => context.go(destinations[i].route),
                  labelType: NavigationRailLabelType.all,
                  leading: const SizedBox.shrink(),
                  destinations: [
                    for (final d in destinations)
                      NavigationRailDestination(
                        icon: Tooltip(message: d.label, child: Icon(d.icon)),
                        selectedIcon: Tooltip(message: d.label, child: Icon(d.selectedIcon)),
                        label: Text(d.label.split(' ').first),
                      ),
                  ],
                ),
              ),
              if (u != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Tooltip(
                    message: u.nama,
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: AppTheme.billiardGreen.withValues(alpha: 0.15),
                      child: Text(
                        u.nama.isNotEmpty ? u.nama[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.billiardGreenDark,
                        ),
                      ),
                    ),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: _LogoutButton(showLabel: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tampilan kosong seragam (belum ada data) dengan ikon besar.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? hint;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.billiardGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppTheme.billiardGreen),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.ink),
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Pusatkan konten dengan lebar maksimal supaya layout rapi di monitor lebar.
class CenteredContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const CenteredContent({
    super.key,
    required this.child,
    this.maxWidth = AppTheme.kContentMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// AppBar seragam halaman konten dalam shell responsif.
/// Di layar sempit, tombol aksi otomatis pindah ke baris bawah judul
/// supaya tidak overflow.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBack;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final hasActions = actions != null && actions!.isNotEmpty;
    final backButton = (showBackButton || onBack != null)
        ? Container(
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 22),
              color: AppTheme.ink,
              onPressed: onBack ??
                  () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
            ),
          )
        : null;

    final titleBlock = Row(
      children: [
        ?backButton,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitle!,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    final actionWrap = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions ?? const [],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 640 && hasActions;
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 12),
                actionWrap,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: titleBlock),
              if (hasActions) ...[const SizedBox(width: 12), actionWrap],
            ],
          );
        },
      ),
    );
  }
}
