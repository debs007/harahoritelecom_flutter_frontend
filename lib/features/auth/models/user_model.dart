// lib/features/auth/models/user_model.dart
class UserModel {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String role;
  final int loyaltyPoints;

  const UserModel({required this.id, required this.name, required this.email,
      this.phone, this.avatarUrl, required this.role, this.loyaltyPoints = 0});

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
    id: j['id'], name: j['name'], email: j['email'],
    phone: j['phone'], avatarUrl: j['avatar'], role: j['role'] ?? 'customer',
    loyaltyPoints: (j['loyalty_points'] as num?)?.toInt() ?? 0,
  );

  UserModel copyWith({String? name, String? email, String? phone, String? avatarUrl}) =>
      UserModel(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        role: role,
        loyaltyPoints: loyaltyPoints,
      );

  bool get isAdmin => role == 'admin';
}