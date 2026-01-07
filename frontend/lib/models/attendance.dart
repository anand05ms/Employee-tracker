// lib/models/attendance.dart
class Attendance {
  final String id;
  final String employeeId;
  final String date;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final String? checkInAddress;
  final String? checkOutAddress;
  final int? estimatedTimeToOffice;
  final int? distanceFromOffice;
  final double totalHours;
  final String status;

  Attendance({
    required this.id,
    required this.employeeId,
    required this.date,
    required this.checkInTime,
    this.checkOutTime,
    this.checkInAddress,
    this.checkOutAddress,
    this.estimatedTimeToOffice,
    this.distanceFromOffice,
    this.totalHours = 0,
    required this.status,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['_id'] ?? '',
      employeeId: json['employeeId'] ?? '',
      date: json['date'] ?? '',
      checkInTime: DateTime.parse(json['checkInTime']),
      checkOutTime: json['checkOutTime'] != null
          ? DateTime.parse(json['checkOutTime'])
          : null,
      checkInAddress: json['checkInAddress'],
      checkOutAddress: json['checkOutAddress'],
      estimatedTimeToOffice: json['estimatedTimeToOffice'],
      distanceFromOffice: json['distanceFromOffice'],
      totalHours: (json['totalHours'] ?? 0).toDouble(),
      status: json['status'] ?? 'CHECKED_IN',
    );
  }

  bool get isCheckedIn => status == 'CHECKED_IN';
  bool get isCheckedOut => status == 'CHECKED_OUT';
}
