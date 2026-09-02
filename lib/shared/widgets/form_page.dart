import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Scaffold seragam untuk halaman form CRUD (bukan modal).
/// AppBar + konten scroll dengan lebar maksimal supaya rapi di desktop
/// maupun mobile (responsive).
class FormPage extends StatelessWidget {
  final String title;
  final Widget child;
  final bool saving;
  final VoidCallback? onSave;
  final String? saveLabel;
  final String? hint;

  const FormPage({
    super.key,
    required this.title,
    required this.child,
    this.saving = false,
    this.onSave,
    this.saveLabel = 'Simpan',
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hint != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.tableReserved.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hint!,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92600A)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                child,
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: onSave == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                ),
                child: FilledButton(
                  onPressed: saving ? null : onSave,
                  child: saving
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(saveLabel!),
                ),
              ),
            ),
    );
  }
}