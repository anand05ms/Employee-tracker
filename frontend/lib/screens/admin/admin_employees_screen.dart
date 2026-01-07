// lib/screens/admin/admin_employees_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../models/user.dart';

class AdminEmployeesScreen extends StatefulWidget {
  const AdminEmployeesScreen({Key? key}) : super(key: key);

  @override
  State<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminEmployeesScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();
  late TabController _tabController;

  List<User> _allEmployees = [];
  List<Map<String, dynamic>> _checkedInEmployees = [];
  List<User> _notCheckedInEmployees = [];
  List<Map<String, dynamic>> _reachedEmployees = []; // ✅ NEW: In Office

  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 4, vsync: this); // ✅ Changed from 3 to 4
    _loadData();
    _setupSocketConnection();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  // 🔄 AUTO-REFRESH EVERY 5 SECONDS
  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      print('🔄 Auto-refreshing employees list (every 15s)...');
      _loadData();
    });
  }

  // 📡 SOCKET CONNECTION FOR REAL-TIME UPDATES
  Future<void> _setupSocketConnection() async {
    try {
      final token = await _apiService.getToken();
      if (token != null) {
        _socketService.connect(token);
        _socketService.joinAdminRoom();

        // Listen to real-time status changes
        _socketService.socket?.on('employee_status_changed', (data) {
          print(
              '📍 Employee status changed: ${data['type']} - ${data['employeeName']}');
          _loadData(); // Refresh all tabs
        });
      }
    } catch (e) {
      print('❌ Socket connection error: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _apiService.getAllEmployees(),
        _apiService.getCheckedInEmployees(),
        _apiService.getNotCheckedInEmployees(),
        _apiService.getReachedEmployees(), // ✅ NEW: Get reached employees
        _apiService.getDashboardStats(),
      ]);

      setState(() {
        _allEmployees = results[0] as List<User>;
        _checkedInEmployees = results[1] as List<Map<String, dynamic>>;
        _notCheckedInEmployees = results[2] as List<User>;
        _reachedEmployees = results[3] as List<Map<String, dynamic>>; // ✅ NEW
        _stats = results[4] as Map<String, dynamic>;
        _isLoading = false;
      });

      print(
          '✅ Loaded: ${_allEmployees.length} total, ${_checkedInEmployees.length} checked in, ${_reachedEmployees.length} in office');
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Stats card
          if (_stats != null)
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(
                      'Total',
                      '${_stats!['totalEmployees'] ?? 0}',
                      Icons.people,
                      Colors.blue,
                    ),
                    _buildStatColumn(
                      'Checked In',
                      '${_stats!['checkedInToday'] ?? 0}',
                      Icons.check_circle,
                      Colors.green,
                    ),
                    _buildStatColumn(
                      'Not Checked In',
                      '${_stats!['notCheckedIn'] ?? 0}',
                      Icons.pending,
                      Colors.orange,
                    ),
                  ],
                ),
              ),
            ),

          // Tabs - ✅ NOW 4 TABS
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
            isScrollable: true, // ✅ Make tabs scrollable for 4 tabs
            tabs: [
              Tab(
                text: 'All (${_allEmployees.length})',
                icon: const Icon(Icons.people),
              ),
              Tab(
                text: 'Checked In (${_checkedInEmployees.length})',
                icon: const Icon(Icons.check_circle),
              ),
              Tab(
                text: 'Not Checked In (${_notCheckedInEmployees.length})',
                icon: const Icon(Icons.pending),
              ),
              Tab(
                text: 'In Office (${_reachedEmployees.length})', // ✅ NEW TAB
                icon: const Icon(Icons.business),
              ),
            ],
          ),

          // Tab views - ✅ NOW 4 TAB VIEWS
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAllEmployeesList(),
                      _buildCheckedInEmployeesList(),
                      _buildNotCheckedInEmployeesList(),
                      _buildInOfficeEmployeesList(), // ✅ NEW TAB VIEW
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadData,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildStatColumn(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildAllEmployeesList() {
    if (_allEmployees.isEmpty) {
      return const Center(
        child: Text('No employees found'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _allEmployees.length,
        itemBuilder: (context, index) {
          final employee = _allEmployees[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text(
                  employee.name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                employee.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (employee.employeeId != null)
                    Text('ID: ${employee.employeeId}'),
                  if (employee.department != null) Text(employee.department!),
                  if (employee.phone != null) Text(employee.phone!),
                ],
              ),
              trailing: Icon(
                employee.isActive ? Icons.check_circle : Icons.cancel,
                color: employee.isActive ? Colors.green : Colors.red,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCheckedInEmployeesList() {
    if (_checkedInEmployees.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No employees checked in today',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _checkedInEmployees.length,
        itemBuilder: (context, index) {
          final data = _checkedInEmployees[index];
          final employee = data['employee'];
          final attendance = data['attendance'];
          final location = data['location'];

          final checkInTime = DateTime.parse(attendance['checkInTime']);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text(
                  employee['name'][0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                employee['name'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Checked in: ${DateFormat('hh:mm a').format(checkInTime.toLocal())}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  if (attendance['checkInAddress'] != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            attendance['checkInAddress'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (attendance['distanceFromOffice'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Distance: ${(attendance['distanceFromOffice'] / 1000).toStringAsFixed(1)} km',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'On the way',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotCheckedInEmployeesList() {
    if (_notCheckedInEmployees.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.celebration, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'All employees checked in!',
              style: TextStyle(fontSize: 16, color: Colors.green),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _notCheckedInEmployees.length,
        itemBuilder: (context, index) {
          final employee = _notCheckedInEmployees[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey,
                child: Text(
                  employee.name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                employee.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (employee.employeeId != null)
                    Text('ID: ${employee.employeeId}'),
                  if (employee.department != null) Text(employee.department!),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Absent',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[900],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ NEW: BUILD IN OFFICE EMPLOYEES LIST
  Widget _buildInOfficeEmployeesList() {
    if (_reachedEmployees.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No employees in office yet',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _reachedEmployees.length,
        itemBuilder: (context, index) {
          final data = _reachedEmployees[index];
          final employee = data['employee'];
          final attendance = data['attendance'];

          final checkInTime = attendance['checkInTime'] != null
              ? DateTime.parse(attendance['checkInTime'])
              : null;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green,
                child: Text(
                  employee['name'][0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                employee['name'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (employee['employeeId'] != null) ...[
                    const SizedBox(height: 4),
                    Text('ID: ${employee['employeeId']}'),
                  ],
                  if (employee['department'] != null)
                    Text(employee['department']),
                  if (checkInTime != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 16, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'Arrived: ${DateFormat('hh:mm a').format(checkInTime.toLocal())}',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 28),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'In Office',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
