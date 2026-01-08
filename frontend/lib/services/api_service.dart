// // lib/services/api_service.dart
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import '../models/user.dart';
// import '../models/attendance.dart';

// class ApiService {
//   // ✅ CHANGE THIS TO YOUR IP ADDRESS
//   static const String baseUrl =
//       'https://vickey-neustic-avoidably.ngrok-free.dev/api';

//   // For Android emulator: http://10.0.2.2:5000/api
//   // For real device: http://YOUR_IP:5000/api (e.g., http://192.168.1.4:5000/api)

//   final storage = const FlutterSecureStorage();

//   // ==================== TOKEN MANAGEMENT ====================

//   Future<Map<String, String>> _getHeaders() async {
//     final token = await storage.read(key: 'token');
//     return {
//       'Content-Type': 'application/json',
//       if (token != null) 'Authorization': 'Bearer $token',
//     };
//   }

//   Future<void> saveToken(String token) async {
//     await storage.write(key: 'token', value: token);
//   }

//   Future<String?> getToken() async {
//     return await storage.read(key: 'token');
//   }

//   Future<void> clearToken() async {
//     await storage.delete(key: 'token');
//   }

//   // ==================== AUTHENTICATION ====================

//   // Login
//   Future<Map<String, dynamic>> login(String email, String password) async {
//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/auth/login'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({'email': email, 'password': password}),
//       );

//       final data = jsonDecode(response.body);

//       if (response.statusCode == 200 && data['success']) {
//         await saveToken(data['data']['token']);
//         return data;
//       } else {
//         throw Exception(data['message'] ?? 'Login failed');
//       }
//     } catch (e) {
//       throw Exception('Login error: $e');
//     }
//   }

//   // Register
//   Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/auth/register'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode(userData),
//       );

//       final data = jsonDecode(response.body);

//       if (response.statusCode == 201 && data['success']) {
//         await saveToken(data['data']['token']);
//         return data;
//       } else {
//         throw Exception(data['message'] ?? 'Registration failed');
//       }
//     } catch (e) {
//       throw Exception('Registration error: $e');
//     }
//   }

//   // Get current user
//   Future<User> getCurrentUser() async {
//     try {
//       final headers = await _getHeaders();
//       final response = await http.get(
//         Uri.parse('$baseUrl/auth/me'),
//         headers: headers,
//       );

//       final data = jsonDecode(response.body);

//       if (response.statusCode == 200 && data['success']) {
//         return User.fromJson(data['data']['user']);
//       } else {
//         throw Exception(data['message'] ?? 'Failed to fetch user');
//       }
//     } catch (e) {
//       throw Exception('Get user error: $e');
//     }
//   }

//   // ==================== EMPLOYEE ENDPOINTS ====================

//   // Check In
//   Future<Map<String, dynamic>> checkIn(
//     double latitude,
//     double longitude,
//     String address,
//   ) async {
//     try {
//       final headers = await _getHeaders();
//       final response = await http.post(
//         Uri.parse('$baseUrl/employee/check-in'),
//         headers: headers,
//         body: jsonEncode({
//           'latitude': latitude,
//           'longitude': longitude,
//           'address': address,
//         }),
//       );

//       final data = jsonDecode(response.body);

//       if (response.statusCode == 201 && data['success']) {
//         return data;
//       } else {
//         throw Exception(data['message'] ?? 'Check-in failed');
//       }
//     } catch (e) {
//       throw Exception('Check-in error: $e');
//     }
//   }

//   // Check Out
//   Future<Map<String, dynamic>> checkOut(
//     double latitude,
//     double longitude,
//     String address,
//   ) async {
//     try {
//       final headers = await _getHeaders();
//       final response = await http.post(
//         Uri.parse('$baseUrl/employee/check-out'),
//         headers: headers,
//         body: jsonEncode({
//           'latitude': latitude,
//           'longitude': longitude,
//           'address': address,
//         }),
//       );

//       final data = jsonDecode(response.body);

//       if (response.statusCode == 200 && data['success']) {
//         return data;
//       } else {
//         throw Exception(data['message'] ?? 'Check-out failed');
//       }
//     } catch (e) {
//       throw Exception('Check-out error: $e');
//     }
//   }

//   // Update Location
//   Future<Map<String, dynamic>> updateLocation(
//     double latitude,
//     double longitude,
//     String address,
//   ) async {
//     try {
//       final headers = await _getHeaders();
//       final response = await http.post(
//         Uri.parse('$baseUrl/employee/location'),
//         headers: headers,
//         body: jsonEncode({
//           'latitude': latitude,
//           'longitude': longitude,
//           'address': address,
//         }),
//       );

//       final data = jsonDecode(response.body);
//       return data;
//     } catch (e) {
//       print('❌ Location update error: $e');
//       return {'success': false, 'message': e.toString()};
//     }
//   }

//   // Get My Status
//   Future<Map<String, dynamic>> getMyStatus() async {
//     try {
//       final headers = await _getHeaders();
//       final response = await http.get(
//         Uri.parse('$baseUrl/employee/status'),
//         headers: headers,
//       );

//       final data = jsonDecode(response.body);

//       if (response.statusCode == 200 && data['success']) {
//         return data['data'];
//       } else {
//         throw Exception(data['message'] ?? 'Failed to fetch status');
//       }
//     } catch (e) {
//       throw Exception('Get status error: $e');
//     }
//   }

//   // ==================== ADMIN ENDPOINTS ====================

//   // Get All Employees
//   Future<List<User>> getAllEmployees() async {
//     try {
//       final headers = await _getHeaders();
//       final response = await http.get(
//         Uri.parse('$baseUrl/admin/employees'),
//         headers: headers,
//       );

//       final data = jsonDecode(response.body);

//       if (response.statusCode == 200 && data['success']) {
//         // ✅ FIX: Proper type casting
//         final employeesList = data['data']['employees'] as List;
//         return employeesList
//             .map((e) => User.fromJson(e as Map<String, dynamic>))
//             .toList();
//       } else {
//         throw Exception(data['message'] ?? 'Failed to fetch employees');
//       }
//     } catch (e) {
//       print('❌ Error fetching all employees: $e');
//       throw Exception('Get employees error: $e');
//     }
//   }

//   // Get Checked-In Employees (on the way)
//   // In getCheckedInEmployees() method
//   Future<List<dynamic>> getCheckedInEmployees() async {
//     final token = await getToken();

//     // ✅ ADD THIS DEBUG LOG
//     final url = '$baseUrl/admin/checked-in-employees';
//     print('🌐 Calling URL: $url');
//     print('📍 baseUrl is: $baseUrl');

//     final response = await http.get(
//       Uri.parse(url),
//       headers: {
//         'Authorization': 'Bearer $token',
//       },
//     );

//     print('📡 Response status: ${response.statusCode}');
//     print(
//         '📄 Response body: ${response.body.substring(0, 100)}...'); // First 100 chars

//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       return data['data'] ?? [];
//     } else {
//       throw Exception('Failed to get employees');
//     }
//   }

//   // Get Not Checked-In Employees
//   Future<List<User>> getNotCheckedInEmployees() async {
//     try {
//       final headers = await _getHeaders();
//       final response = await http.get(
//         Uri.parse('$baseUrl/admin/not-checked-in-employees'),
//         headers: headers,
//       );

//       final data = jsonDecode(response.body);

//       if (response.statusCode == 200 && data['success']) {
//         // ✅ FIX: Proper type casting
//         final employeesList = data['data']['employees'] as List;
//         return employeesList
//             .map((e) => User.fromJson(e as Map<String, dynamic>))
//             .toList();
//       } else {
//         throw Exception(
//             data['message'] ?? 'Failed to fetch not checked-in employees');
//       }
//     } catch (e) {
//       print('❌ Error fetching not checked-in employees: $e');
//       throw Exception('Get not checked-in employees error: $e');
//     }
//   }

//   // Get Reached Employees (in office)
//   Future<List<Map<String, dynamic>>> getReachedEmployees() async {
//     try {
//       final headers = await _getHeaders();
//       final response = await http.get(
//         Uri.parse('$baseUrl/admin/reached-employees'),
//         headers: headers,
//       );

//       final data = jsonDecode(response.body);

//       if (response.statusCode == 200 && data['success']) {
//         // ✅ FIX: Proper type casting
//         final employeesList = data['data']['employees'] as List;
//         return employeesList
//             .map((e) => Map<String, dynamic>.from(e as Map))
//             .toList();
//       } else {
//         throw Exception(data['message'] ?? 'Failed to fetch reached employees');
//       }
//     } catch (e) {
//       print('❌ Error fetching reached employees: $e');
//       throw Exception('Get reached employees error: $e');
//     }
//   }

//   // Get Dashboard Stats
//   Future<Map<String, dynamic>> getDashboardStats() async {
//     try {
//       final headers = await _getHeaders();
//       final response = await http.get(
//         Uri.parse('$baseUrl/admin/dashboard-stats'),
//         headers: headers,
//       );

//       final data = jsonDecode(response.body);

//       if (response.statusCode == 200 && data['success']) {
//         return Map<String, dynamic>.from(data['data']);
//       } else {
//         throw Exception(data['message'] ?? 'Failed to fetch stats');
//       }
//     } catch (e) {
//       print('❌ Error fetching dashboard stats: $e');
//       throw Exception('Get stats error: $e');
//     }
//   }

//   // ==================== ATTENDANCE HISTORY ====================

//   // Get My Attendance History
//   Future<List<Attendance>> getMyAttendance({
//     DateTime? startDate,
//     DateTime? endDate,
//   }) async {
//     try {
//       final headers = await _getHeaders();
//       String url = '$baseUrl/employee/attendance';

//       if (startDate != null && endDate != null) {
//         url +=
//             '?startDate=${startDate.toIso8601String()}&endDate=${endDate.toIso8601String()}';
//       }

//       final response = await http.get(
//         Uri.parse(url),
//         headers: headers,
//       );

//       final data = jsonDecode(response.body);

//       if (response.statusCode == 200 && data['success']) {
//         final attendanceList = data['data']['attendance'] as List;
//         return attendanceList
//             .map((e) => Attendance.fromJson(e as Map<String, dynamic>))
//             .toList();
//       } else {
//         throw Exception(data['message'] ?? 'Failed to fetch attendance');
//       }
//     } catch (e) {
//       print('❌ Error fetching attendance: $e');
//       throw Exception('Get attendance error: $e');
//     }
//   }

//   // ==================== UTILITY METHODS ====================

//   // Test Connection
//   Future<bool> testConnection() async {
//     try {
//       final response = await http
//           .get(
//             Uri.parse(baseUrl.replaceAll('/api', '/')),
//           )
//           .timeout(const Duration(seconds: 5));

//       return response.statusCode == 200;
//     } catch (e) {
//       print('❌ Connection test failed: $e');
//       return false;
//     }
//   }

//   // Get Server Status
//   Future<Map<String, dynamic>> getServerStatus() async {
//     try {
//       final response = await http.get(
//         Uri.parse(baseUrl.replaceAll('/api', '/')),
//       );

//       if (response.statusCode == 200) {
//         return jsonDecode(response.body);
//       } else {
//         throw Exception('Server not responding');
//       }
//     } catch (e) {
//       throw Exception('Server status error: $e');
//     }
//   }
// }
// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../models/attendance.dart';

class ApiService {
  // ✅ YOUR NGROK URL
  static const String baseUrl =
      'https://vickey-neustic-avoidably.ngrok-free.dev/api';

  final storage = const FlutterSecureStorage();

  // ==================== TOKEN MANAGEMENT ====================

  // ✅ ADD NGROK BYPASS HEADER
  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'token');
    return {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true', // ✅ BYPASS NGROK WARNING
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> saveToken(String token) async {
    await storage.write(key: 'token', value: token);
  }

  Future<String?> getToken() async {
    return await storage.read(key: 'token');
  }

  Future<void> clearToken() async {
    await storage.delete(key: 'token');
  }

  // ==================== AUTHENTICATION ====================

  // Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true', // ✅ ADD HERE TOO
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        await saveToken(data['data']['token']);
        return data;
      } else {
        throw Exception(data['message'] ?? 'Login failed');
      }
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  // Register
  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode(userData),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success']) {
        await saveToken(data['data']['token']);
        return data;
      } else {
        throw Exception(data['message'] ?? 'Registration failed');
      }
    } catch (e) {
      throw Exception('Registration error: $e');
    }
  }

  // Get current user
  Future<User> getCurrentUser() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return User.fromJson(data['data']['user']);
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch user');
      }
    } catch (e) {
      throw Exception('Get user error: $e');
    }
  }

  // ==================== EMPLOYEE ENDPOINTS ====================

  // Check In
  // Check In - FIX THE URL
  Future<Map<String, dynamic>> checkIn(
    double latitude,
    double longitude,
    String address,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(
            '$baseUrl/employee/check-in'), // ✅ CORRECT: /employee/check-in
        headers: headers,
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success']) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Check-in failed');
      }
    } catch (e) {
      throw Exception('Check-in error: $e');
    }
  }

// Update Location - FIX THE URL
  Future<Map<String, dynamic>> updateLocation(
    double latitude,
    double longitude,
    String address,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(
            '$baseUrl/employee/location'), // ✅ CORRECT: /employee/location
        headers: headers,
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
        }),
      );

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      print('❌ Location update error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

// Check Out - FIX THE URL
  Future<Map<String, dynamic>> checkOut(
    double latitude,
    double longitude,
    String address,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(
            '$baseUrl/employee/check-out'), // ✅ CORRECT: /employee/check-out
        headers: headers,
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Check-out failed');
      }
    } catch (e) {
      throw Exception('Check-out error: $e');
    }
  }

// Get My Status - FIX THE URL
  Future<Map<String, dynamic>> getMyStatus() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/employee/status'), // ✅ CORRECT: /employee/status
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return data['data'];
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch status');
      }
    } catch (e) {
      throw Exception('Get status error: $e');
    }
  }

  // ==================== ADMIN ENDPOINTS ====================

  // Get All Employees
  Future<List<User>> getAllEmployees() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/employees'),
        headers: headers,
      );

      print('📡 getAllEmployees Response status: ${response.statusCode}');
      print('📄 getAllEmployees Body: ${response.body.substring(0, 100)}...');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final employeesList = data['data']['employees'] as List;
        return employeesList
            .map((e) => User.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch employees');
      }
    } catch (e) {
      print('❌ Error fetching all employees: $e');
      throw Exception('Get employees error: $e');
    }
  }

  // Get Checked-In Employees (on the way)
  // Get Checked-In Employees (on the way)
  Future<List<dynamic>> getCheckedInEmployees() async {
    try {
      final headers = await _getHeaders();
      final url = '$baseUrl/admin/checked-in-employees';

      print('🌐 Calling URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('📡 Response status: ${response.statusCode}');
      print('📄 Response body: ${response.body.substring(0, 200)}...');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success']) {
          // ✅ FIX: Handle nested structure
          final employeesData = data['data'];

          // Check if employees is directly in data or nested
          List<dynamic> employees;
          if (employeesData is List) {
            employees = employeesData;
          } else if (employeesData is Map &&
              employeesData['employees'] != null) {
            employees = employeesData['employees'] as List;
          } else {
            employees = [];
          }

          print('✅ Successfully got ${employees.length} checked-in employees');
          return employees;
        } else {
          throw Exception(data['message'] ?? 'Failed to get employees');
        }
      } else {
        throw Exception('Failed to get employees: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in getCheckedInEmployees: $e');
      throw Exception('Get checked-in employees error: $e');
    }
  }

  // Get Not Checked-In Employees
  Future<List<User>> getNotCheckedInEmployees() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/not-checked-in-employees'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final employeesList = data['data']['employees'] as List;
        return employeesList
            .map((e) => User.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(
            data['message'] ?? 'Failed to fetch not checked-in employees');
      }
    } catch (e) {
      print('❌ Error fetching not checked-in employees: $e');
      throw Exception('Get not checked-in employees error: $e');
    }
  }

  // Get Reached Employees (in office)
  Future<List<Map<String, dynamic>>> getReachedEmployees() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/reached-employees'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final employeesList = data['data']['employees'] as List;
        return employeesList
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch reached employees');
      }
    } catch (e) {
      print('❌ Error fetching reached employees: $e');
      throw Exception('Get reached employees error: $e');
    }
  }

  // Get Dashboard Stats
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/dashboard-stats'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return Map<String, dynamic>.from(data['data']);
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch stats');
      }
    } catch (e) {
      print('❌ Error fetching dashboard stats: $e');
      throw Exception('Get stats error: $e');
    }
  }

  // ==================== ATTENDANCE HISTORY ====================

  // Get My Attendance History
  Future<List<Attendance>> getMyAttendance({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final headers = await _getHeaders();
      String url = '$baseUrl/employee/attendance';

      if (startDate != null && endDate != null) {
        url +=
            '?startDate=${startDate.toIso8601String()}&endDate=${endDate.toIso8601String()}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final attendanceList = data['data']['attendance'] as List;
        return attendanceList
            .map((e) => Attendance.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch attendance');
      }
    } catch (e) {
      print('❌ Error fetching attendance: $e');
      throw Exception('Get attendance error: $e');
    }
  }

  // ==================== UTILITY METHODS ====================

  // Test Connection
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse(baseUrl.replaceAll('/api', '/')),
        headers: {'ngrok-skip-browser-warning': 'true'},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Connection test failed: $e');
      return false;
    }
  }

  // Get Server Status
  Future<Map<String, dynamic>> getServerStatus() async {
    try {
      final response = await http.get(
        Uri.parse(baseUrl.replaceAll('/api', '/')),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Server not responding');
      }
    } catch (e) {
      throw Exception('Server status error: $e');
    }
  }
}
