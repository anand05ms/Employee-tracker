// lib/services/background_location_service.dart
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'api_service.dart';

class BackgroundLocationService {
  static final BackgroundLocationService _instance =
      BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  final ApiService _apiService = ApiService();
  StreamSubscription<Position>? _positionSubscription;
  bool _isTracking = false;

  // Start tracking location
  Future<void> startTracking() async {
    if (_isTracking) {
      print('⚠️ Already tracking location');
      return;
    }

    print('🎯 Starting background location tracking...');
    _isTracking = true;

    // Listen to position stream (updates every 10 meters)
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen(
      (Position position) async {
        print(
            '📍 Location changed: ${position.latitude}, ${position.longitude}');
        await _sendLocationUpdate(position);
      },
      onError: (error) {
        print('❌ Location stream error: $error');
      },
    );

    print('✅ Background location tracking started');
  }

  // Send location update to backend
  Future<void> _sendLocationUpdate(Position position) async {
    try {
      // Get address from coordinates
      String address = 'Moving';
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          address = '${place.street ?? ''}, ${place.locality ?? ''}';
        }
      } catch (e) {
        print('⚠️ Failed to get address: $e');
      }

      print('🚀 Sending location update to backend...');

      final response = await _apiService.updateLocation(
        position.latitude,
        position.longitude,
        address,
      );

      if (response['success']) {
        print('✅ Location update sent successfully');

        // Check if reached office
        if (response['data']?['hasReachedOffice'] == true) {
          print('🎉 Employee reached office!');
          await stopTracking(); // Stop tracking when reached
        }
      } else {
        print('⚠️ Location update failed: ${response['message']}');
      }
    } catch (e) {
      print('❌ Error sending location update: $e');
    }
  }

  // Stop tracking
  Future<void> stopTracking() async {
    print('🛑 Stopping background location tracking...');
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
    print('✅ Background location tracking stopped');
  }

  // Check if currently tracking
  bool get isTracking => _isTracking;
}
