/// Re-export provider pengaturan global dari modul tables (di mana Firestore
/// repository & stream settings didefinisikan), supaya feature settings dan
/// consumer lain cukup import satu tempat.
library;

export '../../tables/providers/tables_providers.dart'
    show settingsProvider, settingsRepositoryProvider;