import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/auth_shell.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final identifier = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (identifier.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Email/username dan password wajib diisi.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).login(identifier: identifier, password: pass);
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = _friendlyAuthError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthError(String raw) {
    if (raw.contains('invalid-credential') || raw.contains('wrong-password') || raw.contains('user-not-found')) {
      return 'Email/username atau password salah.';
    }
    if (raw.contains('invalid-email')) return 'Format email tidak valid.';
    if (raw.contains('too-many-requests')) return 'Terlalu banyak percobaan. Coba lagi nanti.';
    if (raw.contains('network-request-failed')) return 'Koneksi internet bermasalah.';
    return 'Gagal masuk. Periksa koneksi dan coba lagi.';
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Selamat Datang',
      subtitle: 'Masuk untuk mengelola meja, kasir, dan laporan billiard Anda.',
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.text,
            autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(
              labelText: 'Email atau Username',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            onSubmitted: (_) => _login(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
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
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.tableUsed, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppTheme.tableUsed, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _login,
            child: _loading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text('Masuk'),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('atau', style: TextStyle(color: Colors.grey.shade500)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: () => context.go('/register'),
            child: const Text('Daftar sebagai Admin pertama'),
          ),
        ],
      ),
    );
  }
}