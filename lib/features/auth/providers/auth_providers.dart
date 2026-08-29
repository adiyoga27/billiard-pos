import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/app_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

/// Stream user yang sedang login (null = belum login).
final authControllerProvider = StreamProvider<AppUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.userStream();
});

/// Role user saat ini (kemudahan akses di UI).
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authControllerProvider).valueOrNull;
});

/// Daftar staff (admin & kasir) — untuk filter laporan & manajemen staff.
final staffStreamProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(authRepositoryProvider).staffStream();
});