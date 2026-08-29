import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notification/services/notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: YesBilliardApp()));
}

/// Scroll dengan drag mouse/trackpad supaya nyaman di desktop & web.
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };
}

class YesBilliardApp extends ConsumerStatefulWidget {
  const YesBilliardApp({super.key});

  @override
  ConsumerState<YesBilliardApp> createState() => _YesBilliardAppState();
}

class _YesBilliardAppState extends ConsumerState<YesBilliardApp> {
  @override
  void initState() {
    super.initState();
    // Inisialisasi notifikasi (FCM + local) sekali saat app dibuka.
    // Router dibutuhkan untuk deep-link dari tap notifikasi ke route.
    final service = NotificationService();
    Future.microtask(() => service.init(router: ref.read(routerProvider)));
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Yes Billiard — POS & Meja',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      scrollBehavior: AppScrollBehavior(),
      routerConfig: router,
    );
  }
}