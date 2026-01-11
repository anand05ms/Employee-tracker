// lib/screens/employee/employee_home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/socket_service.dart';
import '../../services/offline_queue_service.dart';
import '../../models/attendance.dart';
import '../auth/login_screen.dart';

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen>
    with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final SocketService _socketService = SocketService();
  final OfflineQueueService _offlineQueue = OfflineQueueService();

  bool _isLoading = false;
  bool _isCheckedIn = false;
  bool _hasReachedOffice = false;
  Attendance? _todayAttendance;
  Position? _currentPosition;
  int? _estimatedTimeToOffice;
  int? _distanceFromOffice;

  // Real-time tracking
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _backupTimer;
  bool _isTracking = false;

  // Office location
  static const double officeLat = 9.88162;
  static const double officeLng = 78.11582;
  static const double officeRadius = 500;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLocationTracking();
    _socketService.disconnect();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // ✅ Handle app lifecycle (background/foreground)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('📱 App resumed - checking socket connection');
      if (_isCheckedIn && !_hasReachedOffice && !_socketService.isConnected) {
        _socketService.forceReconnect();
      }
    } else if (state == AppLifecycleState.paused) {
      print('📱 App paused - tracking continues in background');
    }
  }

  // ✅ Initialize all services
  Future<void> _initializeServices() async {
    // 1. Check location permission
    final hasPermission = await _checkLocationPermission();
    if (!hasPermission) return;

    // 2. Initialize offline queue
    await _offlineQueue.initialize();

    // 3. Monitor connectivity
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none && _offlineQueue.hasQueuedUpdates) {
        print(
            '🌐 Connectivity restored - processing ${_offlineQueue.queueSize} queued updates');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '📡 Syncing ${_offlineQueue.queueSize} pending updates...'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.blue,
          ),
        );
      }
    });

    // 4. Load status and location
    await _loadStatus();
    await _getCurrentLocation();

    // 5. Initialize socket
    await _initializeSocket();
  }

  Future<bool> _ensureLocationServiceEnabled() async {
    final enabled = await Geolocator.isLocationServiceEnabled();

    if (!enabled && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.gps_off, color: Colors.red),
              SizedBox(width: 8),
              Text('Turn on Location'),
            ],
          ),
          content: const Text(
            'Location services are turned off.\n\nPlease enable GPS to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Geolocator.openLocationSettings();
              },
              child: const Text('Open Settings'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  // ✅ Check and request location permission
  Future<bool> _checkLocationPermission() async {
    final status = await Permission.locationWhenInUse.status;

    if (status.isGranted) {
      // Check if location service is enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDialog();
        return false;
      }
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.locationWhenInUse.request();
      if (result.isGranted) {
        return true;
      }
    }

    if (status.isPermanentlyDenied) {
      _showPermissionDeniedDialog();
      return false;
    }

    _showPermissionRequiredDialog();
    return false;
  }

  String _friendlyApiError(dynamic e) {
    final msg = e.toString();

    if (msg.contains('already checked in')) {
      return 'You are already checked in today';
    }
    if (msg.contains('not checked in')) {
      return 'You are not checked in yet';
    }
    if (msg.contains('Location')) {
      return 'Unable to fetch location. Please enable GPS';
    }
    if (msg.contains('Network')) {
      return 'Network error. Please check your internet';
    }
    if (msg.contains('timeout')) {
      return 'Server taking too long. Try again';
    }
    return 'Something went wrong. Please try again';
  }

  // ✅ Show location service disabled dialog
  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.red),
            SizedBox(width: 12),
            Text('Location Service Disabled'),
          ],
        ),
        content: const Text(
          'Please enable location services to use this app.\n\nGo to Settings → Location → Turn On',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // ✅ Show permission required dialog
  void _showPermissionRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Colors.orange),
            SizedBox(width: 12),
            Text('Location Permission Required'),
          ],
        ),
        content: const Text(
          'This app needs location permission to track your attendance and distance to office.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _checkLocationPermission();
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  // ✅ Show permission permanently denied dialog
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red),
            SizedBox(width: 12),
            Text('Permission Denied'),
          ],
        ),
        content: const Text(
          'Location permission is permanently denied. Please enable it in app settings.\n\nSettings → Apps → EmpTracker → Permissions → Location',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
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
      if (!await _ensureLocationServiceEnabled()) return;

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

  // 🚀 START REAL-TIME TRACKING
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
    print('🟢 Mode: Position Stream + Backup Timer');
    print('🟢 Updates: Every 10m movement + 15s backup');
    print('🟢 ========================================');

    // Send first update
    _sendLocationUpdate();

    // Position stream
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) async {
        print('\n📡 ===== STREAM UPDATE =====');
        print(
            '📍 ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}');

        if (_currentPosition != null) {
          final moved = _locationService.calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          print('🚶 Moved ${moved.toStringAsFixed(1)}m');
        }

        await _handlePositionUpdate(position, user);
      },
      onError: (error) => print('❌ Position stream error: $error'),
      cancelOnError: false,
    );

    // Backup timer
    _backupTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      print('\n⏰ Backup check (#${timer.tick})');

      try {
        final newPosition = await _locationService.getCurrentPosition();

        if (_currentPosition != null) {
          final moved = _locationService.calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            newPosition.latitude,
            newPosition.longitude,
          );

          print('📏 Distance since last: ${moved.toStringAsFixed(1)}m');

          if (moved > 5) {
            print('⚠️ Backup update (moved ${moved.toStringAsFixed(1)}m)');
            await _handlePositionUpdate(newPosition, user);
          } else if (timer.tick % 4 == 0) {
            print('💓 Heartbeat update');
            await _handlePositionUpdate(newPosition, user);
          }
        } else {
          await _handlePositionUpdate(newPosition, user);
        }
      } catch (e) {
        print('❌ Backup failed: $e');
      }
    });
  }

  // 📍 HANDLE POSITION UPDATE
  Future<void> _handlePositionUpdate(Position position, user) async {
    try {
      final distance = _locationService.calculateDistance(
        position.latitude,
        position.longitude,
        officeLat,
        officeLng,
      );

      final isInOffice = distance <= officeRadius;
      print('🏢 Distance: ${distance.toStringAsFixed(0)}m');

      // ✅ TRY TO UPDATE BACKEND (with timeout)
      try {
        final response = await _apiService
            .updateLocation(
              position.latitude,
              position.longitude,
              'Moving - ${DateTime.now().toString().substring(11, 19)}',
            )
            .timeout(const Duration(seconds: 10));

        print('✅ Backend updated');

        // Check if reached office
        if (response['data']?['hasReachedOffice'] == true &&
            !_hasReachedOffice) {
          print('🎉 REACHED OFFICE!');

          setState(() {
            _hasReachedOffice = true;
            _isCheckedIn = false;
          });

          _stopLocationTracking();

          if (mounted) {
            _showReachedOfficeDialog();
          }
          return;
        }

        // Broadcast via Socket
        if (_socketService.isConnected) {
          _socketService.sendLocationUpdate({
            'employeeId': user?.id ?? '',
            'employeeName': user?.name ?? 'Unknown',
            'latitude': position.latitude,
            'longitude': position.longitude,
            'isInOffice': isInOffice,
            'hasReachedOffice': response['data']?['hasReachedOffice'] ?? false,
            'timestamp': DateTime.now().toIso8601String(),
          });
          print('📡 Socket.io sent');
        }
      } catch (e) {
        print('❌ Backend update failed: $e');

        // ✅ ADD TO OFFLINE QUEUE
        await _offlineQueue.addLocationUpdate(
          position.latitude,
          position.longitude,
          'Offline - ${DateTime.now().toString().substring(11, 19)}',
        );

        // Show notification
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '📡 Offline - ${_offlineQueue.queueSize} updates queued'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

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

  Future<void> _sendLocationUpdate() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      print('📡 Getting GPS location...');
      final position = await _locationService.getCurrentPosition();

      await _handlePositionUpdate(position, user);
    } catch (e) {
      print('❌ Location update failed: $e');
    }
  }

  void _stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    _backupTimer?.cancel();
    _backupTimer = null;

    if (mounted) {
      setState(() => _isTracking = false);
    }

    print('🔴 LOCATION TRACKING STOPPED');
  }

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
              child: Text('Welcome to Office!', style: TextStyle(fontSize: 20)),
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
            Text('You are now marked as present.', textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadStatus();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCheckIn() async {
    await _getCurrentLocation();
    if (!await _ensureLocationServiceEnabled()) return;

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get location. Please try again.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print(
          '📍 Check-in: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');

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
        _showReachedOfficeDialog();
      } else {
        print('🚀 Starting tracking...');
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
            content: Text(_friendlyApiError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleCheckOut() async {
    if (!await _ensureLocationServiceEnabled()) return;

    if (_currentPosition == null) {
      await _getCurrentLocation();
      if (_currentPosition == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to get location'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
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
            content: Text(_friendlyApiError(e)),
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

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Colors.blue[700]),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Dashboard'),
        actions: [
          // Network status
          StreamBuilder<ConnectivityResult>(
            stream: Connectivity().onConnectivityChanged,
            builder: (context, snapshot) {
              final isOnline = snapshot.data != ConnectivityResult.none;
              final queueSize = _offlineQueue.queueSize;

              if (!isOnline || queueSize > 0) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.orange[100] : Colors.red[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOnline ? Icons.cloud_queue : Icons.cloud_off,
                            size: 14,
                            color: isOnline ? Colors.orange : Colors.red,
                          ),
                          if (queueSize > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '$queueSize',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isOnline ? Colors.orange : Colors.red,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

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
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      if (user?.employeeId != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${user?.employeeId}',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 14),
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
                                  fontSize: 18, fontWeight: FontWeight.bold),
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
                                    'Auto-tracking',
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

              // Distance info
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
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 64),
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
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            if (_isTracking)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Live',
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
}
