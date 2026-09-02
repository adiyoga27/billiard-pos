import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shell halaman auth responsif:
/// - Desktop/tablet landscape: panel branding gradient di kiri + form di kanan.
/// - Mobile: form di tengah dengan logo di atas.
class AuthShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget form;
  final Widget? footer;

  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            Expanded(flex: 5, child: _BrandingPanel()),
            Expanded(
              flex: 6,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppTheme.ink),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 28),
                        form,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.billiardGreenNeon, AppTheme.billiardGreen],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.billiardGreenNeon.withValues(alpha: 0.30),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(AppTheme.billiardIcon, size: 42, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppTheme.ink),
                  ),
                  const SizedBox(height: 6),
                  Text(
                     subtitle,
                     textAlign: TextAlign.center,
                     style: Theme.of(context)
                         .textTheme
                         .bodyMedium
                         ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                   ),
                   const SizedBox(height: 28),
                   form,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandingPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF065F46), Color(0xFF0B1220)],
        ),
      ),
      child: Stack(
        children: [
          // Dekorasi lingkaran lembut
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: const Icon(AppTheme.billiardIcon, size: 56, color: Colors.white),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Yes Billiard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'POS & Manajemen Meja Billiard',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: const [
                    _FeatureTag(icon: Icons.table_restaurant_rounded, label: 'Timer meja real-time'),
                    _FeatureTag(icon: Icons.point_of_sale_rounded, label: 'POS walk-in'),
                    _FeatureTag(icon: Icons.bar_chart_rounded, label: 'Laporan otomatis'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 18),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
