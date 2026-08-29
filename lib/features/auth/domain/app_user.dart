enum UserRole { admin, kasir }

extension UserRoleX on UserRole {
  String get label => this == UserRole.admin ? 'Admin' : 'Kasir';

  String get storageValue => this == UserRole.admin ? 'admin' : 'kasir';

  static UserRole fromStorage(String? v) => v == 'admin' ? UserRole.admin : UserRole.kasir;
}

class AppUser {
  final String uid;
  final String nama;
  final String email;
  final UserRole role;

  const AppUser({
    required this.uid,
    required this.nama,
    required this.email,
    required this.role,
  });

  bool get isAdmin => role == UserRole.admin;

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) => AppUser(
        uid: uid,
        nama: map['nama'] as String? ?? 'Kasir',
        email: map['email'] as String? ?? '',
        role: UserRoleX.fromStorage(map['role'] as String?),
      );
}