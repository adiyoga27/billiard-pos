import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/data/settings_repository.dart';
import '../../settings/domain/settings_models.dart';
import '../data/tables_repository.dart';
import '../domain/package_models.dart';
import '../domain/table_models.dart';

final tablesRepositoryProvider = Provider<TablesRepository>((ref) => TablesRepository());

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) => SettingsRepository());

/// Tick global tiap detik — dipakai semua timer/estimasi biaya real-time.
final nowTickProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

final tablesStreamProvider = StreamProvider<List<BillTable>>((ref) {
  return ref.watch(tablesRepositoryProvider).tablesStream();
});

final runningSessionsStreamProvider = StreamProvider<List<TableSession>>((ref) {
  return ref.watch(tablesRepositoryProvider).runningSessionsStream();
});

final packagesStreamProvider = StreamProvider<List<PlayPackage>>((ref) {
  return ref.watch(tablesRepositoryProvider).packagesStream();
});

final settingsProvider = StreamProvider<AppSettings>((ref) {
  return ref.watch(settingsRepositoryProvider).settingsStream();
});

/// Lihat daftar paket yang berlaku untuk sebuah meja pada waktu sekarang.
final applicablePackagesProvider =
    FutureProvider.autoDispose.family<List<PlayPackage>, String>((ref, tableId) async {
  final packages = await ref.watch(packagesStreamProvider.future);
  final now = DateTime.now();
  return packages.where((p) => p.appliesAt(now, tableId)).toList();
});