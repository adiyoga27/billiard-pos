import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/auth_shell.dart';
import '../providers/auth_providers.dart';

/// Registrasi admin PERTAMA. Hanya diizinkan bila belum ada akun sama sekali —
/// setelah ada admin, akun kasir dibuat lewat Modul Pengaturan.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _namaCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _namaCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final nama = _namaCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final pass2 = _pass2Ctrl.text;
    if (nama.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Semua kolom wajib diisi.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password minimal 6 karakter.');
      return;
    }
    if (pass != pass2) {
      setState(() => _error = 'Konfirmasi password tidak cocok.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .registerAdmin(nama: nama, email: email, password: pass);
      if (mounted) context.go('/');
    } catch (e) {
      final msg = e.toString();
      setState(() => _error = msg.contains('email-already-in-use')
          ? 'Email sudah terdaftar.'
          : 'Gagal mendaftar. Periksa koneksi dan coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Daftar Admin',
      subtitle: 'Buat akun admin pertama untuk mengelola bisnis billiard Anda.',
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.tableReserved.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: AppTheme.tableReserved),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Akun pertama otomatis menjadi Admin. Akun kasir berikutnya dibuat oleh admin di menu Pengaturan → Staff.',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _namaCtrl,
            decoration: const InputDecoration(
              labelText: 'Nama lengkap',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _pass2Ctrl,
            obscureText: _obscure,
            onSubmitted: (_) => _register(),
            decoration: const InputDecoration(
              labelText: 'Konfirmasi password',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.tableUsed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: AppTheme.tableUsed, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _register,
            child: _loading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text('Buat Akun Admin'),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Sudah punya akun? Masuk'),
          ),
        ],
      ),
    );
  }
}