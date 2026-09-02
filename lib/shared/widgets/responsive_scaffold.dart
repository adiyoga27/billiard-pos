import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/app_user.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../core/theme/app_theme.dart';

/// Apakah sidebar desktop (>= 1200px) sedang diciutkan ke mode ikon.
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

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
        railLabel: 'Meja',
        icon: AppTheme.billiardIcon,
        selectedIcon: AppTheme.billiardIcon,
        section: 'MEJA & SESI',
      ),
      // Grup KASIR (transaksi tanpa meja)
      _NavDest(
        route: '/pos',
        label: 'Kasir Walk-in',
        railLabel: 'Kasir',
        icon: Icons.point_of_sale_rounded,
        selectedIcon: Icons.point_of_sale_rounded,
        section: 'KASIR',
      ),
      _NavDest(
        route: '/reports',
        label: 'Laporan',
        railLabel: 'Laporan',
        icon: Icons.bar_chart_rounded,
        selectedIcon: Icons.bar_chart_rounded,
        section: 'LAPORAN',
      ),
      if (user?.isAdmin ?? false)
        _NavDest(
          route: '/settings',
          label: 'Pengaturan',
          railLabel: 'Atur',
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
      final collapsed = ref.watch(sidebarCollapsedProvider);
      return Scaffold(
        body: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: collapsed
                  ? _SidebarMini(
                      key: const ValueKey('mini'),
                      user: user,
                      destinations: destinations,
                      selectedIndex: selectedIndex(),
                    )
                  : _Sidebar(
                      key: const ValueKey('full'),
                      user: user,
                      destinations: destinations,
                      selectedIndex: selectedIndex(),
                    ),
            ),
            Expanded(
              child: SafeArea(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: child,
                ),
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
              child: SafeArea(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: child,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(child: child),
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
  final String railLabel;
  final IconData icon;
  final IconData selectedIcon;
  final String? section;

  const _NavDest({
    required this.route,
    required this.label,
    required this.railLabel,
    required this.icon,
    required this.selectedIcon,
    this.section,
  });
}

/// Logo + nama aplikasi (dipakai sidebar & rail).
class _BrandMark extends StatelessWidget {
  final bool compact;
  final bool dark;

  const _BrandMark({this.compact = false, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mark = Container(
      width: compact ? 40 : 44,
      height: compact ? 40 : 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.billiardGreenNeon, AppTheme.billiardGreen],
        ),
        borderRadius: BorderRadius.circular(compact ? 12 : 13),
        boxShadow: [
          BoxShadow(
            color: AppTheme.billiardGreenNeon.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(AppTheme.billiardIcon, color: Colors.white, size: 24),
    );

    if (compact) return mark;

    return Row(
      children: [
        mark,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yes Billiard',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: dark ? Colors.white : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'POS SYSTEM',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: dark ? AppTheme.billiardGreen : AppTheme.billiardGreenNeon,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogoutButton extends ConsumerWidget {
  final bool showLabel;
  final bool dark;

  const _LogoutButton({this.showLabel = true, this.dark = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = dark ? const Color(0xFFFCA5A5) : AppTheme.tableUsed;
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
              Icon(Icons.logout_rounded, size: 20, color: color),
              if (showLabel) ...[
                const SizedBox(width: 8),
                Text(
                  'Keluar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
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

/// Palet warna sidebar gelap (selaras tema dark premium).
abstract final class _Sb {
  static const bg = AppTheme.panel;
  static const text = AppTheme.inkOnDark;
  static const textDim = Color(0xFF93A5C4);
  static const label = Color(0xFF55688C);
}

/// Tombol kecil untuk menciutkan / memperluas sidebar.
class _SidebarToggle extends ConsumerWidget {
  final bool collapsed;

  const _SidebarToggle({required this.collapsed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: collapsed ? 'Perluas menu' : 'Ciutkan menu',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              ref.read(sidebarCollapsedProvider.notifier).state = !collapsed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Icon(
              collapsed
                  ? Icons.keyboard_double_arrow_right_rounded
                  : Icons.keyboard_double_arrow_left_rounded,
              size: 16,
              color: _Sb.textDim,
            ),
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
    super.key,
    required this.user,
    required this.destinations,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = user; // lokal supaya type promotion bekerja di collection literal
    return Material(
      color: _Sb.bg,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: 264,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 14, 20),
                child: Row(
                  children: [
                    const Expanded(child: _BrandMark(dark: true)),
                    const _SidebarToggle(collapsed: false),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                  children: [
                    for (var i = 0; i < destinations.length; i++) ...[
                      if (i == 0 || destinations[i].section != destinations[i - 1].section)
                        _SectionLabel(label: destinations[i].section ?? ''),
                      _NavItem(
                        label: destinations[i].label,
                        icon: i == selectedIndex ? destinations[i].selectedIcon : destinations[i].icon,
                        selected: i == selectedIndex,
                        onTap: () => context.go(destinations[i].route),
                      ),
                    ],
                  ],
                ),
              ),
              if (u != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                  child: _UserCard(user: u),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sidebar diciutkan: hanya ikon + tooltip, menu tetap bisa diakses.
class _SidebarMini extends ConsumerWidget {
  final AppUser? user;
  final List<_NavDest> destinations;
  final int selectedIndex;

  const _SidebarMini({
    super.key,
    required this.user,
    required this.destinations,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = user;
    return Material(
      color: _Sb.bg,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: 76,
          child: Column(
            children: [
              const SizedBox(height: 18),
              const _BrandMark(compact: true),
              const SizedBox(height: 12),
              const _SidebarToggle(collapsed: true),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  children: [
                    for (var i = 0; i < destinations.length; i++)
                      Center(
                        child: _MiniNavItem(
                          label: destinations[i].label,
                          icon: i == selectedIndex
                              ? destinations[i].selectedIcon
                              : destinations[i].icon,
                          selected: i == selectedIndex,
                          onTap: () => context.go(destinations[i].route),
                        ),
                      ),
                  ],
                ),
              ),
              if (u != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Tooltip(
                    message: u.nama,
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.billiardGreenNeon, AppTheme.billiardGreen],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        u.nama.isNotEmpty ? u.nama[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Tooltip(
                  message: 'Keluar',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => ref.read(authRepositoryProvider).logout(),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.tableUsed.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.logout_rounded, size: 17, color: Color(0xFFFCA5A5)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Label grup navigasi (MEJA & SESI, KASIR, LAPORAN, ADMIN).
class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: _Sb.label,
        ),
      ),
    );
  }
}

/// Kartu profil user di dasar sidebar: avatar gradient, nama, badge role,
/// dan tombol keluar terintegrasi.
class _UserCard extends ConsumerWidget {
  final AppUser user;

  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.billiardGreenNeon, AppTheme.billiardGreen],
              ),
              shape: BoxShape.circle,
            ),
            child: Text(
              user.nama.isNotEmpty ? user.nama[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 16),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.nama,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: _Sb.text),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: user.isAdmin
                        ? AppTheme.tableReserved.withValues(alpha: 0.22)
                        : AppTheme.billiardGreen.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    user.role.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: user.isAdmin ? const Color(0xFFFCD34D) : const Color(0xFF6EE7B7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Keluar',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => ref.read(authRepositoryProvider).logout(),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.tableUsed.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout_rounded, size: 17, color: Color(0xFFFCA5A5)),
                ),
              ),
            ),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          hoverColor: Colors.white.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppTheme.billiardGreenNeon, AppTheme.billiardGreen],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppTheme.billiardGreenNeon.withValues(alpha: 0.30),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: selected ? Colors.white : _Sb.textDim,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13.5,
                      color: selected ? _Sb.text : _Sb.textDim,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: selected ? 1 : 0,
                  child: const _ActiveDot(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Item navigasi mode mini (ikon saja + tooltip).
class _MiniNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _MiniNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(13),
            hoverColor: Colors.white.withValues(alpha: 0.06),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.billiardGreenNeon, AppTheme.billiardGreen],
                      )
                    : null,
                borderRadius: BorderRadius.circular(13),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppTheme.billiardGreenNeon.withValues(alpha: 0.30),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : _Sb.textDim,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveDot extends StatelessWidget {
  const _ActiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: AppTheme.billiardGreen,
        shape: BoxShape.circle,
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
      color: _Sb.bg,
      child: Theme(
        data: Theme.of(context).copyWith(
          navigationRailTheme: NavigationRailThemeData(
            backgroundColor: _Sb.bg,
            indicatorColor: AppTheme.billiardGreen.withValues(alpha: 0.18),
            selectedIconTheme: const IconThemeData(color: Colors.white),
            selectedLabelTextStyle:
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
            unselectedIconTheme: const IconThemeData(color: _Sb.textDim),
            unselectedLabelTextStyle:
                const TextStyle(color: _Sb.textDim, fontWeight: FontWeight.w600, fontSize: 11),
            labelType: NavigationRailLabelType.all,
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            width: 92,
            child: Column(
              children: [
                const SizedBox(height: 18),
                const _BrandMark(compact: true),
                const SizedBox(height: 14),
                Expanded(
                  child: NavigationRail(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (i) => context.go(destinations[i].route),
                    labelType: NavigationRailLabelType.all,
                    leading: const SizedBox.shrink(),
                    groupAlignment: -0.9,
                    destinations: [
                      for (final d in destinations)
                        NavigationRailDestination(
                          icon: Tooltip(message: d.label, child: Icon(d.icon)),
                          selectedIcon: Tooltip(message: d.label, child: Icon(d.selectedIcon)),
                          label: Text(d.railLabel),
                        ),
                    ],
                  ),
                ),
                if (u != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Tooltip(
                      message: u.nama,
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppTheme.billiardGreenNeon, AppTheme.billiardGreen],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          u.nama.isNotEmpty ? u.nama[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: _LogoutButton(showLabel: false, dark: true),
                ),
              ],
            ),
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
                border: Border.all(color: AppTheme.billiardGreen.withValues(alpha: 0.20)),
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
                style: TextStyle(
                    fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
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
