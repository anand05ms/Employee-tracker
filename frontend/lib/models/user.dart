// lib/models/user.dart
class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? employeeId;
  final String? phone;
  final String? department;
  final bool isActive;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.employeeId,
    this.phone,
    this.department,
    this.isActive = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'EMPLOYEE',
      employeeId: json['employeeId'],
      phone: json['phone'],
      department: json['department'],
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'role': role,
      'employeeId': employeeId,
      'phone': phone,
      'department': department,
      'isActive': isActive,
    };
  }

  bool get isAdmin => role == 'ADMIN';
  bool get isEmployee => role == 'EMPLOYEE';
}
