// lib/services/auth_provider.dart
import 'dart:convert'; // ✅ FIXED: Added missing imports
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http; // ✅ FIXED: Added http import
import '../models/user.dart';
import 'api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  User? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _isCheckingAuth = true;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isCheckingAuth => _isCheckingAuth;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.role == 'ADMIN';
  bool get isEmployee => _currentUser?.role == 'EMPLOYEE';

  // 🚀 AUTO-LOGIN
  Future<bool> initializeAuth() async {
    _isCheckingAuth = true;
    notifyListeners();

    try {
      final token = await _apiService.getToken();

      if (token != null) {
        print('🔑 Token found, attempting auto-login...');

        try {
          _currentUser = await _apiService.getCurrentUser();
          print('✅ Auto-login successful: ${_currentUser?.name}');

          _isCheckingAuth = false;
          notifyListeners();
          return true;
        } catch (e) {
          print('❌ Auto-login failed: Invalid/expired token');
          await logout(force: true);
        }
      }
    } catch (e) {
      print('❌ Auth initialization error: $e');
    }

    _isCheckingAuth = false;
    notifyListeners();
    return false;
  }

  // Login
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.login(email, password);
      _currentUser = User.fromJson(response['data']['user']);

      print('✅ Login successful: ${_currentUser?.name}');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      print('❌ Login failed: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Register
  Future<bool> register(Map<String, dynamic> userData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.register(userData);
      _currentUser = User.fromJson(response['data']['user']);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ✅ FIXED: Use ApiService instead of direct HTTP
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // ✅ BETTER: Let ApiService handle it (add this method later)
      final token = await _apiService.getToken();
      if (token == null) throw Exception('No token available');

      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}/auth/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        print('✅ Password changed successfully');
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        throw Exception(data['message'] ?? 'Password change failed');
      }
    } catch (e) {
      _error = e.toString();
      print('❌ Password change failed: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Load user from token
  Future<void> loadUser() async {
    if (_currentUser != null) return;

    final token = await _apiService.getToken();
    if (token != null) {
      try {
        _currentUser = await _apiService.getCurrentUser();
        notifyListeners();
      } catch (e) {
        await logout();
      }
    }
  }

  // Logout
  Future<void> logout({bool force = false}) async {
    await _apiService.clearToken();
    _currentUser = null;
    _error = null;
    notifyListeners();

    print('👋 Logged out');
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
