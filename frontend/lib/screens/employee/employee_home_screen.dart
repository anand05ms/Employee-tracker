// lib/screens/employee/employee_home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/socket_service.dart';
import '../../models/attendance.dart';
import '../auth/login_screen.dart';

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final SocketService _socketService = SocketService();

  bool _isLoading = false;
  bool _isCheckedIn = false;
  bool _hasReachedOffice = false;
  Attendance? _todayAttendance;
  Position? _currentPosition;
  int? _estimatedTimeToOffice;
  int? _distanceFromOffice;

  // ✅ Real-time tracking with STREAM
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _backupTimer;
  bool _isTracking = false;

  // Office location
  static const double officeLat = 9.88162;
  static const double officeLng = 78.11582;
  static const double officeRadius = 500; // meters

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _getCurrentLocation();
    _initializeSocket();
  }

  @override
  void dispose() {
    _stopLocationTracking();
    _socketService.disconnect();
    super.dispose();
  }

  Future<void> _initializeSocket() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = await _apiService.getToken();
    if (token != null) {
      _socketService.connect(token);
      _socketService.joinEmployeeRoom(authProvider.currentUser?.id ?? '');
    }
  }

  Future<void> _loadStatus() async {
    try {
      final status = await _apiService.getMyStatus();
      setState(() {
        _isCheckedIn = status['isCheckedIn'] ?? false;
        _hasReachedOffice = status['hasReachedOffice'] ?? false;
        if (status['attendance'] != null) {
          _todayAttendance = Attendance.fromJson(status['attendance']);
        }
      });

      // Start tracking if checked in but not reached office
      if (_isCheckedIn && !_hasReachedOffice && !_isTracking) {
        _startLocationTracking();
      }
    } catch (e) {
      print('Error loading status: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        final distance = _locationService.calculateDistance(
          position.latitude,
          position.longitude,
          officeLat,
          officeLng,
        );
        _distanceFromOffice = distance.round();
        _estimatedTimeToOffice = _locationService.calculateETA(distance);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🚀 START REAL-TIME TRACKING (POSITION STREAM)
  void _startLocationTracking() {
    if (_isTracking) {
      print('⚠️ Already tracking');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    setState(() => _isTracking = true);

    print('🟢 ========================================');
    print('🟢 REAL-TIME LOCATION TRACKING STARTED');
    print('🟢 Mode: Position Stream (auto-updates)');
    print('🟢 Updates when you move 10+ meters');
    print('🟢 ========================================');

    // ✅ SEND FIRST UPDATE IMMEDIATELY
    _sendLocationUpdate();

    // ✅ START POSITION STREAM (updates automatically when moving)
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) async {
        print('\n📡 ===== STREAM UPDATE =====');
        print(
            '📍 Position: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}');

        // Show movement from last position
        if (_currentPosition != null) {
          final moved = _locationService.calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          print('🚶 Moved ${moved.toStringAsFixed(1)}m since last update');
        }

        await _handlePositionUpdate(position, user);
      },
      onError: (error) {
        print('❌ Position stream error: $error');
      },
      cancelOnError: false, // Keep stream alive
    );

    // ✅ BACKUP TIMER (every 30s) - ensures updates even when standing still
    _backupTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      print('\n⏰ Backup timer update (#${timer.tick})');
      await _sendLocationUpdate();
    });
  }

  // 📍 HANDLE POSITION UPDATE
  Future<void> _handlePositionUpdate(Position position, user) async {
    try {
      // Calculate distance from office
      final distance = _locationService.calculateDistance(
        position.latitude,
        position.longitude,
        officeLat,
        officeLng,
      );

      final isInOffice = distance <= officeRadius;

      print('🏢 Distance from office: ${distance.toStringAsFixed(0)}m');

      // Update backend
      final response = await _apiService.updateLocation(
        position.latitude,
        position.longitude,
        'Moving - ${DateTime.now().toString().substring(11, 19)}',
      );

      print('✅ Backend updated');

      // 🎉 CHECK IF REACHED OFFICE
      if (response['data']?['hasReachedOffice'] == true && !_hasReachedOffice) {
        print('🎉 🎉 🎉 REACHED OFFICE! 🎉 🎉 🎉');

        setState(() {
          _hasReachedOffice = true;
          _isCheckedIn = false;
        });

        // Stop tracking
        _stopLocationTracking();

        // Show celebration dialog
        if (mounted) {
          _showReachedOfficeDialog();
        }
        return;
      }

      // Broadcast via Socket.io
      _socketService.sendLocationUpdate({
        'employeeId': user?.id ?? '',
        'employeeName': user?.name ?? 'Unknown',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'isInOffice': isInOffice,
        'hasReachedOffice': response['data']?['hasReachedOffice'] ?? false,
        'timestamp': DateTime.now().toIso8601String(),
      });

      print('📡 Socket.io broadcast sent');

      // Update UI
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _distanceFromOffice = distance.round();
          _estimatedTimeToOffice = _locationService.calculateETA(distance);
        });
      }

      print('✅ Update complete (${distance.round()}m from office)');
    } catch (e) {
      print('❌ Position update failed: $e');
    }
  }

  // 📍 SEND LOCATION UPDATE (for manual/timer calls)
  Future<void> _sendLocationUpdate() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      print('📡 Getting fresh GPS location...');
      final position = await _locationService.getCurrentPosition();

      await _handlePositionUpdate(position, user);
    } catch (e) {
      print('❌ Location update failed: $e');
    }
  }

  // 🛑 STOP TRACKING
  void _stopLocationTracking() {
    // Cancel position stream
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    // Cancel backup timer
    _backupTimer?.cancel();
    _backupTimer = null;

    if (mounted) {
      setState(() => _isTracking = false);
    }

    print('🔴 ========================================');
    print('🔴 LOCATION TRACKING STOPPED');
    print('🔴 ========================================');
  }

  // 🎉 SHOW REACHED OFFICE DIALOG
  void _showReachedOfficeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.celebration, color: Colors.green[700], size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Welcome to Office!',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text(
              '🎉 You have reached the office!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'You are now marked as present.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadStatus(); // Refresh status
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCheckIn() async {
    // Get FRESH location before check-in
    await _getCurrentLocation();

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get your location. Please try again.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print(
          '📍 Check-in location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');

      final response = await _apiService.checkIn(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        'Current Location',
      );

      final hasReached = response['data']?['hasReachedOffice'] ?? false;

      setState(() {
        _isCheckedIn = !hasReached;
        _hasReachedOffice = hasReached;
        _isLoading = false;
      });

      if (hasReached) {
        // Already at office
        _showReachedOfficeDialog();
      } else {
        // ✅ START TRACKING IMMEDIATELY
        print('🚀 Starting location tracking...');
        _startLocationTracking();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Checked in successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadStatus();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check-in failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleCheckOut() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting your location...'),
          backgroundColor: Colors.orange,
        ),
      );
      await _getCurrentLocation();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _apiService.checkOut(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        'Current Location',
      );

      setState(() {
        _isCheckedIn = false;
        _hasReachedOffice = false;
        _isLoading = false;
      });

      _stopLocationTracking();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Checked out successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadStatus();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check-out failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    _stopLocationTracking();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Dashboard'),
        actions: [
          // Tracking indicator
          if (_isTracking)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadStatus();
          await _getCurrentLocation();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, ${user?.name ?? "Employee"}!',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user?.department ?? 'Employee',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                      if (user?.employeeId != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${user?.employeeId}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Status card
              Card(
                color: _hasReachedOffice
                    ? Colors.green[50]
                    : (_isCheckedIn ? Colors.blue[50] : Colors.orange[50]),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        _hasReachedOffice
                            ? Icons.celebration
                            : (_isCheckedIn
                                ? Icons.directions_walk
                                : Icons.pending),
                        color: _hasReachedOffice
                            ? Colors.green
                            : (_isCheckedIn ? Colors.blue : Colors.orange),
                        size: 40,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _hasReachedOffice
                                  ? '✅ In Office'
                                  : (_isCheckedIn
                                      ? '🚶 On the way'
                                      : 'Not Checked In'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_todayAttendance != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Checked in: ${DateFormat('hh:mm a').format(_todayAttendance!.checkInTime.toLocal())}',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                            if (_isTracking) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.radar,
                                      size: 16, color: Colors.blue[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Auto-tracking (Stream)',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Distance info (only if not reached)
              if (_isCheckedIn &&
                  !_hasReachedOffice &&
                  _currentPosition != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.navigation, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Distance to Office',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildInfoItem(
                              'Distance',
                              _distanceFromOffice != null
                                  ? '${(_distanceFromOffice! / 1000).toStringAsFixed(1)} km'
                                  : 'Calculating...',
                              Icons.straighten,
                            ),
                            _buildInfoItem(
                              'ETA',
                              _estimatedTimeToOffice != null
                                  ? '$_estimatedTimeToOffice min'
                                  : 'Calculating...',
                              Icons.access_time,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Action button
              if (!_hasReachedOffice)
                SizedBox(
                  height: 120,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : (_isCheckedIn ? _handleCheckOut : _handleCheckIn),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCheckedIn ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isCheckedIn ? Icons.logout : Icons.login,
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isCheckedIn ? 'Check Out' : 'Check In',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

              // Reached office message
              if (_hasReachedOffice) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '🎉 You are in the office!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Marked present at ${_todayAttendance != null ? DateFormat('hh:mm a').format(_todayAttendance!.checkInTime.toLocal()) : ""}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleCheckOut,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Check Out',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Current location
              if (_currentPosition != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Current Location',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_isTracking)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Live Stream',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        Text(
                          'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        Text(
                          'Accuracy: ±${_currentPosition!.accuracy.toStringAsFixed(0)}m',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Colors.blue[700]),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
