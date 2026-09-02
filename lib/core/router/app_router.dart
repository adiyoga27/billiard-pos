import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/pos/presentation/checkout_screen.dart';
import '../../features/pos/presentation/order_picker_screen.dart';
import '../../features/pos/presentation/pos_screen.dart';
import '../../features/pos/presentation/transaction_detail_screen.dart';
import '../../features/pos/providers/pos_providers.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/settings/domain/settings_models.dart';
import '../../features/settings/presentation/category_form_screen.dart';
import '../../features/settings/presentation/category_management_screen.dart';
import '../../features/settings/presentation/general_settings_form_screen.dart';
import '../../features/settings/presentation/package_form_screen.dart';
import '../../features/settings/presentation/package_management_screen.dart';
import '../../features/settings/presentation/product_form_screen.dart';
import '../../features/settings/presentation/product_management_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/staff_form_screen.dart';
import '../../features/settings/presentation/staff_management_screen.dart';
import '../../features/settings/presentation/table_form_screen.dart';
import '../../features/settings/presentation/table_management_screen.dart';
import '../../features/tables/domain/table_models.dart';
import '../../features/tables/presentation/add_package_screen.dart';
import '../../features/tables/presentation/charge_form_screen.dart';
import '../../features/tables/presentation/dashboard_screen.dart';
import '../../features/tables/presentation/discount_form_screen.dart';
import '../../features/tables/presentation/extend_form_screen.dart';
import '../../features/tables/presentation/start_session_screen.dart';
import '../../features/tables/presentation/table_detail_screen.dart';

/// Baca `extra` route dengan type aman (form screens menerima data via extra).
T? extraOf<T>(GoRouterState state) {
  final extra = state.extra;
  if (extra is T) return extra;
  return null;
}

/// Definisi terpusat semua route aplikasi.
/// Route pakai named path + path parameter supaya bisa deep-link dari
/// notifikasi FCM: payload `{"route": "/transaction/inv10002"}`.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final authAsync = ref.read(authControllerProvider);
      final onAuthPage = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      // Saat stream auth masih memuat (mis. baru selesai login atau baru
      // buka app), jangan redirect — hindari terlempar ke halaman login.
      if (authAsync.isLoading) return null;

      final loggedIn = authAsync.valueOrNull != null;
      if (!loggedIn && !onAuthPage) return '/login';
      if (loggedIn && onAuthPage) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/pos',
        name: 'pos',
        builder: (context, state) => const PosScreen(),
      ),
      GoRoute(
        path: '/table/:tableId',
        name: 'tableDetail',
        builder: (context, state) => TableDetailScreen(tableId: state.pathParameters['tableId']!),
      ),
      GoRoute(
        path: '/transaction/:invoiceId',
        name: 'transactionDetail',
        builder: (context, state) =>
            TransactionDetailScreen(invoiceId: state.pathParameters['invoiceId']!),
      ),
      GoRoute(
        path: '/reports',
        name: 'reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/tables',
        name: 'settingsTables',
        builder: (context, state) => const TableManagementScreen(),
      ),
      GoRoute(
        path: '/settings/packages',
        name: 'settingsPackages',
        builder: (context, state) => const PackageManagementScreen(),
      ),
      GoRoute(
        path: '/settings/products',
        name: 'settingsProducts',
        builder: (context, state) => const ProductManagementScreen(),
      ),
      GoRoute(
        path: '/settings/categories',
        name: 'settingsCategories',
        builder: (context, state) => const CategoryManagementScreen(),
      ),
      GoRoute(
        path: '/settings/staff',
        name: 'settingsStaff',
        builder: (context, state) => const StaffManagementScreen(),
      ),
      // ===== Form screens (halaman penuh, bukan modal) =====
      GoRoute(
        path: '/settings/table-form',
        name: 'tableForm',
        builder: (context, state) => TableFormScreen(table: extraOf(state)),
      ),
      GoRoute(
        path: '/settings/package-form',
        name: 'packageForm',
        builder: (context, state) => PackageFormScreen(paket: extraOf(state)),
      ),
      GoRoute(
        path: '/settings/product-form',
        name: 'productForm',
        builder: (context, state) => ProductFormScreen(product: extraOf(state)),
      ),
      GoRoute(
        path: '/settings/category-form',
        name: 'categoryForm',
        builder: (context, state) => CategoryFormScreen(category: extraOf(state)),
      ),
      GoRoute(
        path: '/settings/staff-form',
        name: 'staffForm',
        builder: (context, state) => const StaffFormScreen(),
      ),
      GoRoute(
        path: '/settings/settings-form',
        name: 'settingsForm',
        builder: (context, state) =>
            GeneralSettingsFormScreen(settings: extraOf(state)),
      ),
      GoRoute(
        path: '/start-session',
        name: 'startSession',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            return StartSessionScreen(
              table: extra['table'] as BillTable,
              settings: extra['settings'] as AppSettings,
            );
          }
          return const DashboardScreen();
        },
      ),
      GoRoute(
        path: '/extend-form',
        name: 'extendForm',
        builder: (context, state) {
          final session = extraOf<TableSession>(state);
          if (session == null) return const DashboardScreen();
          return ExtendFormScreen(session: session);
        },
      ),
      GoRoute(
        path: '/charge-form',
        name: 'chargeForm',
        builder: (context, state) {
          final session = extraOf<TableSession>(state);
          if (session == null) return const DashboardScreen();
          return ChargeFormScreen(session: session);
        },
      ),
      GoRoute(
        path: '/discount-form',
        name: 'discountForm',
        builder: (context, state) {
          final session = extraOf<TableSession>(state);
          if (session == null) return const DashboardScreen();
          return DiscountFormScreen(session: session);
        },
      ),
      GoRoute(
        path: '/add-package',
        name: 'addPackage',
        builder: (context, state) {
          final session = extraOf<TableSession>(state);
          if (session == null) return const DashboardScreen();
          return AddPackageScreen(session: session);
        },
      ),
      GoRoute(
        path: '/order-picker',
        name: 'orderPicker',
        builder: (context, state) => OrderPickerScreen(
          tableId: state.extra as String,
        ),
      ),
      GoRoute(
        path: '/checkout',
        name: 'checkout',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            return CheckoutScreen(
              items: extra['items'] as List<CartItem>,
              sessionToFinalize: extra['sessionToFinalize'] as TableSession?,
              title: extra['title'] as String?,
              onSuccess: extra['onSuccess'] as VoidCallback?,
            );
          }
          return const DashboardScreen();
        },
      ),
    ],
  );
  return router;
});

/// Navigasi dari deep-link (payload notifikasi FCM), misal `{"route": "/table/abc"}`.
/// Dipanggil sekali dari notifikasi yang di-tap.
void navigateToRoute(GoRouter router, String route) {
  if (route.startsWith('/')) {
    try {
      router.go(route);
    } catch (_) {
      // route tidak dikenal — fallback ke dashboard
      router.go('/');
    }
  }
}