// lib/screens/admin/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import 'admin_map_screen.dart';

import 'admin_employees_screen.dart';
import '../auth/change_password_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;
  final ApiService _apiService = ApiService();

  final List<Widget> _screens = [
    const AdminMapScreen(), // Live Map - Only CHECKED_IN employees
    const AdminEmployeesScreen(), // Employees list
  ];

  // ✅ FIXED: Simple refresh function
  Future<void> _refreshAllData() async {
    try {
      await Future.wait([
        _apiService.getDashboardStats(),
        _apiService.getCheckedInEmployees(),
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dashboard refreshed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          // ✅ PASSWORD BUTTON
          IconButton(
            icon: const Icon(Icons.key),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChangePasswordScreen(),
              ),
            ),
            tooltip: 'Change Password',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAllData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAllData, // ✅ FIXED
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.blue[700],
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Live Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Employees',
          ),
        ],
      ),
    );
  }
}
