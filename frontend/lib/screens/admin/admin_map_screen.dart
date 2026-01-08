// lib/screens/admin/admin_map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';

class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({Key? key}) : super(key: key);

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();
  final MapController _mapController = MapController();

  List<Marker> _employeeMarkers = [];
  Map<String, Map<String, dynamic>> _employeeData = {};
  Map<String, AnimationController> _pulseAnimations = {};
  bool _isLoading = true;
  bool _isRefreshing = false;
  int _checkedInCount = 0;

  Timer? _refreshTimer;
  double _currentZoom = 13.0;

  // Office location
  static const double officeLat = 9.88162;
  static const double officeLng = 78.11582;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _setupSocketConnection();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _socketService.disconnect();
    _refreshTimer?.cancel();
    for (var controller in _pulseAnimations.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeMap() async {
    await _loadCheckedInEmployees();
  }

  // Setup Socket.IO
  Future<void> _setupSocketConnection() async {
    try {
      final token = await _apiService.getToken();
      if (token != null) {
        _socketService.connect(token);
        _socketService.joinAdminRoom();

        print('✅ Admin joined Socket.io room');

        _socketService.socket?.on('employee_status_changed', (data) {
          print('📍 Status update: ${data['type']} - ${data['employeeName']}');
          _handleEmployeeUpdate(data);
        });

        _socketService.socket?.on('location_update', (data) {
          print('📍 Location update: ${data['employeeName']}');
          _handleEmployeeUpdate(data);
        });
      }
    } catch (e) {
      print('❌ Socket connection error: $e');
    }
  }

  // Auto-refresh every 15 seconds
  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!_isLoading && !_isRefreshing) {
        print('🔄 Auto-refreshing employees (every 15s)...');
        _loadCheckedInEmployees();
      }
    });
  }

  // Handle real-time updates
  void _handleEmployeeUpdate(Map<String, dynamic> data) {
    if (!mounted) return;

    final type = data['type'];
    final employeeId = data['employeeId'];
    final latitude = data['latitude'];
    final longitude = data['longitude'];

    if (latitude == null || longitude == null) return;

    setState(() {
      if (type == 'REACHED_OFFICE' || type == 'CHECKED_OUT') {
        // Remove employee marker
        _employeeData.remove(employeeId);
        _employeeMarkers.removeWhere(
          (m) => m.key.toString().contains(employeeId),
        );
        _pulseAnimations[employeeId]?.dispose();
        _pulseAnimations.remove(employeeId);
        _checkedInCount = _employeeData.length;
      } else if (type == 'CHECKED_IN' || type == 'LOCATION_UPDATE') {
        // Update or add employee marker
        if (data['hasReachedOffice'] != true) {
          _employeeData[employeeId] = data;
          _createPulseAnimation(employeeId);
          _updateEmployeeMarkerSmooth(data);
          _checkedInCount = _employeeData.length;
        }
      }
    });
  }

  // Load checked-in employees
  Future<void> _loadCheckedInEmployees() async {
    if (_isLoading && _isRefreshing) return;

    setState(() {
      if (_isLoading) {
        _isLoading = true;
      } else {
        _isRefreshing = true;
      }
    });

    try {
      print('🔄 Loading checked-in employees...');

      final employeesData = await _apiService.getCheckedInEmployees();

      print('✅ Received ${employeesData.length} employees');

      final markers = <Marker>[];
      _employeeData.clear();

      for (var empData in employeesData) {
        try {
          final emp = empData as Map<String, dynamic>;
          final employeeInfo = emp['employee'] as Map<String, dynamic>;
          final name = employeeInfo['name'] as String? ?? 'Unknown';

          print('🔍 Processing employee: $name');

          final lat = emp['latitude'] as double?;
          final lng = emp['longitude'] as double?;

          print('📍 Coordinates: $lat, $lng');

          if (lat != null && lng != null) {
            final employeeId = employeeInfo['_id'] as String;

            // Store employee data
            _employeeData[employeeId] = {
              'employeeId': employeeId,
              'employeeName': name,
              'employeeDepartment': employeeInfo['department'],
              'employeePhone': employeeInfo['phone'],
              'latitude': lat,
              'longitude': lng,
              'address': emp['address'],
              'lastUpdate': emp['lastUpdate'],
              'checkInTime': emp['attendance']?['checkInTime'],
            };

            // Create pulse animation
            _createPulseAnimation(employeeId);

            // Create marker
            final marker = _createEmployeeMarker(_employeeData[employeeId]!);
            markers.add(marker);

            print('✅ Added marker for $name');
          } else {
            print('⚠️ No location for $name');
          }
        } catch (e) {
          print('❌ Error processing employee: $e');
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _employeeMarkers = markers;
          _checkedInCount = markers.length;
          _isLoading = false;
          _isRefreshing = false;
        });
        print('✅ Map loaded with ${markers.length} employee markers');
      }
    } catch (e) {
      print('❌ Error loading employees: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Create pulse animation
  void _createPulseAnimation(String employeeId) {
    if (_pulseAnimations.containsKey(employeeId)) return;

    final controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimations[employeeId] = controller;
  }

  // Update marker smoothly
  void _updateEmployeeMarkerSmooth(Map<String, dynamic> data) {
    final employeeId = data['employeeId'];
    _employeeMarkers.removeWhere((m) => m.key.toString().contains(employeeId));
    _employeeMarkers.add(_createEmployeeMarker(data));
  }

  // Create employee marker
  Marker _createEmployeeMarker(Map<String, dynamic> data) {
    final employeeId = data['employeeId'];
    final latitude = data['latitude'];
    final longitude = data['longitude'];
    final employeeName = data['employeeName'] ?? 'Employee';

    final pulseController = _pulseAnimations[employeeId];

    return Marker(
      key: Key(employeeId),
      point: LatLng(latitude, longitude),
      width: 120,
      height: 120,
      child: GestureDetector(
        onTap: () => _showEmployeeDetails(data),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pulseController != null)
              AnimatedBuilder(
                animation: pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (pulseController.value * 0.3);
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 50 * scale,
                        height: 50 * scale,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(
                            0.3 - (pulseController.value * 0.2),
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_walk,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  );
                },
              )
            else
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                employeeName.split(' ')[0],
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show employee details
  void _showEmployeeDetails(Map<String, dynamic> data) {
    final checkInTime = data['checkInTime'] != null
        ? DateTime.parse(data['checkInTime'])
        : null;
    final lastUpdate =
        data['lastUpdate'] != null ? DateTime.parse(data['lastUpdate']) : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue,
                  child:
                      const Icon(Icons.person, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['employeeName'] ?? 'Employee',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '🚶 On the way',
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (checkInTime != null)
              _buildDetailRow(
                'Check-in Time',
                DateFormat('hh:mm a').format(checkInTime.toLocal()),
                Icons.access_time,
              ),
            if (lastUpdate != null)
              _buildDetailRow(
                'Last Update',
                _getTimeAgo(lastUpdate),
                Icons.update,
              ),
            if (data['employeeDepartment'] != null)
              _buildDetailRow(
                'Department',
                data['employeeDepartment'],
                Icons.business,
              ),
            if (data['employeePhone'] != null)
              _buildDetailRow(
                'Phone',
                data['employeePhone'],
                Icons.phone,
              ),
            _buildDetailRow(
              'Location',
              data['address'] ?? 'Unknown',
              Icons.location_on,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _mapController.move(
                    LatLng(data['latitude'], data['longitude']),
                    16,
                  );
                },
                icon: const Icon(Icons.my_location),
                label: const Text('Center on Map'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('hh:mm a').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Flutter Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(officeLat, officeLng),
              initialZoom: 13.0,
              minZoom: 3.0,
              maxZoom: 19.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
                pinchZoomThreshold: 0.5,
                scrollWheelVelocity: 0.005,
              ),
              onMapEvent: (MapEvent event) {
                if (mounted && event is MapEventMove) {
                  setState(() {
                    _currentZoom = _mapController.camera.zoom;
                  });
                }
              },
              keepAlive: true,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.emptracker.app',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: const LatLng(officeLat, officeLng),
                    radius: 500,
                    useRadiusInMeter: true,
                    color: Colors.blue.withOpacity(0.1),
                    borderColor: Colors.blue,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: const LatLng(officeLat, officeLng),
                    width: 120,
                    height: 100,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.business,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'TCE Office',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              MarkerLayer(markers: _employeeMarkers),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap', onTap: () {}),
                ],
              ),
            ],
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Loading employees...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Stats card
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.directions_walk,
                        color: Colors.blue[700], size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'On the Way',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            '$_checkedInCount Employee${_checkedInCount != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isRefreshing)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
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
                  ],
                ),
              ),
            ),
          ),

          // Zoom controls
          Positioned(
            bottom: 100,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _currentZoom + 1,
                    );
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add, color: Colors.blue),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _currentZoom - 1,
                    );
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.remove, color: Colors.blue),
                ),
              ],
            ),
          ),

          // Center on office button
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'center',
              onPressed: () {
                _mapController.move(
                  const LatLng(officeLat, officeLng),
                  13,
                );
              },
              backgroundColor: Colors.blue,
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
