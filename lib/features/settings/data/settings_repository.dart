import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/settings_models.dart';

class SettingsRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const _docId = 'global';

  Stream<AppSettings> settingsStream() {
    return _db.collection('settings').doc(_docId).snapshots().map((snap) {
      if (!snap.exists) return const AppSettings();
      return AppSettings.fromMap(snap.data()!);
    });
  }

  Future<void> updateSettings(AppSettings settings) async {
    await _db.collection('settings').doc(_docId).set(settings.toMap(), SetOptions(merge: true));
  }
}