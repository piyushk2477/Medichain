class AppUser {
  final String id;
  final String email;
  final String fullName;
  final String role;

  AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      email: map['email'] as String,
      fullName: map['full_name'] as String,
      role: map['role'] as String,
    );
  }
}
