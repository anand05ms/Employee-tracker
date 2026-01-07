// lib/models/location.dart
class LocationData {
  final String id;
  final String employeeId;
  final double latitude;
  final double longitude;
  final String? address;
  final double? accuracy;
  final DateTime timestamp;
  final bool isInOffice;

  LocationData({
    required this.id,
    required this.employeeId,
    required this.latitude,
    required this.longitude,
    this.address,
    this.accuracy,
    required this.timestamp,
    this.isInOffice = false,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      id: json['_id'] ?? '',
      employeeId: json['employeeId'] ?? '',
      latitude: (json['location']?['coordinates']?[1] ?? 0.0).toDouble(),
      longitude: (json['location']?['coordinates']?[0] ?? 0.0).toDouble(),
      address: json['address'],
      accuracy: json['accuracy']?.toDouble(),
      timestamp:
          DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      isInOffice: json['isInOffice'] ?? false,
    );
  }
}
