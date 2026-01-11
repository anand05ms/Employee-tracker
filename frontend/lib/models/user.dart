// lib/models/user.dart
class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? department;
  final String? employeeId;
  final String role;
  final bool isActive;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.department,
    this.employeeId,
    required this.role,
    this.isActive = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      department: json['department'],
      employeeId: json['employeeId'],
      role: json['role'] ?? 'EMPLOYEE',
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'department': department,
      'employeeId': employeeId,
      'role': role,
      'isActive': isActive,
    };
  }
}
