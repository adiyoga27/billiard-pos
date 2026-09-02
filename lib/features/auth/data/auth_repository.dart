import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../../firebase_options.dart';
import '../domain/app_user.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<AppUser?> userStream() {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      try {
        final snap = await _db.collection('users').doc(user.uid).get();
        if (!snap.exists) return null;
        return AppUser.fromMap(user.uid, snap.data()!);
      } catch (_) {
        // Gagal baca dokumen (mis. jaringan putus sesaat): tetap anggap
        // masih login supaya tidak tiba-tiba kembali ke halaman login.
        return AppUser(
          uid: user.uid,
          nama: user.displayName ?? 'User',
          email: user.email ?? '',
          role: UserRole.kasir,
        );
      }
    });
  }

  String? get currentUid => _auth.currentUser?.uid;

  /// Login dengan email atau username. Username di-resolve ke email lewat
  /// koleksi `usernames` (read publik supaya bisa dipakai saat belum login).
  Future<void> login({required String identifier, required String password}) async {
    var email = identifier.trim();
    if (!email.contains('@')) {
      final snap = await _db.collection('usernames').doc(email.toLowerCase()).get();
      if (!snap.exists) throw Exception('user-not-found');
      email = (snap.data()!['email'] as String).trim();
    }
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Username otomatis diambil dari bagian depan email (sebelum @).
  /// Jika sudah dipakai email lain, diberi akhiran angka.
  Future<String> _resolveUsername(String email) async {
    final trimmed = email.trim();
    final base = trimmed.toLowerCase().split('@').first;
    var username = base;
    var suffix = 2;
    while (true) {
      final snap = await _db.collection('usernames').doc(username).get();
      if (!snap.exists || snap.data()?['email'] == trimmed) return username;
      username = '$base${suffix++}';
    }
  }

  Future<void> logout() => _auth.signOut();

  /// Registrasi admin pertama: buat akun + tulis doc users/{uid} role admin.
  /// Aturan Firestore mengizinkan self-create role admin (lihat firestore.rules).
  Future<AppUser> registerAdmin({
    required String nama,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = cred.user!.uid;
    await _db.collection('users').doc(uid).set({
      'nama': nama.trim(),
      'email': email.trim(),
      'role': UserRole.admin.storageValue,
      'created_at': FieldValue.serverTimestamp(),
    });
    await _db.collection('usernames').doc(await _resolveUsername(email)).set({
      'uid': uid,
      'email': email.trim(),
    });
    return AppUser(uid: uid, nama: nama.trim(), email: email.trim(), role: UserRole.admin);
  }

  /// Admin membuat akun kasir.
  /// Dibuat lewat REST API Identity Toolkit supaya sesi admin TIDAK terganti
  /// (createUserWithEmailAndPassword di SDK akan sign-in sebagai user baru).
  Future<void> createKasir({
    required String nama,
    required String email,
    required String password,
  }) async {
    final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
    final uri = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'returnSecureToken': true,
      }),
    );
    if (res.statusCode != 200) {
      final msg = (jsonDecode(res.body)['error']?['message'] as String?) ?? 'Gagal membuat akun';
      throw Exception(msg);
    }
    final uid = jsonDecode(res.body)['localId'] as String;
    await _db.collection('users').doc(uid).set({
      'nama': nama.trim(),
      'email': email.trim(),
      'role': UserRole.kasir.storageValue,
      'created_at': FieldValue.serverTimestamp(),
    });
    await _db.collection('usernames').doc(await _resolveUsername(email)).set({
      'uid': uid,
      'email': email.trim(),
    });
  }

  Stream<List<AppUser>> staffStream() {
    return _db.collection('users').snapshots().map((snap) =>
        snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList());
  }

  Future<void> setRole(String uid, UserRole role) async {
    await _db.collection('users').doc(uid).update({'role': role.storageValue});
  }

  Future<void> deleteStaff(String uid) async {
    await _db.collection('users').doc(uid).delete();
    // Catatan: akun Firebase Auth-nya tidak bisa dihapus dari client —
    // untuk produksi gunakan Admin SDK / Cloud Function.
  }
}