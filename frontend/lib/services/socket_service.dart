// lib/services/socket_service.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static const String serverUrl = 'http://localhost:5000';
  // Replace with your PC's IP address

  IO.Socket? socket;
  bool isConnected = false;

  // Connect to Socket.io server
  void connect(String token) {
    socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
    );

    socket?.onConnect((_) {
      print('✅ Socket.io Connected');
      isConnected = true;
    });

    socket?.onDisconnect((_) {
      print('❌ Socket.io Disconnected');
      isConnected = false;
    });

    socket?.onError((error) {
      print('❌ Socket.io Error: $error');
    });
  }

  // Join admin room
  void joinAdminRoom() {
    if (socket != null && isConnected) {
      socket?.emit('join_admin');
      print('👤 Joined admin room');
    }
  }

  // Join employee room
  void joinEmployeeRoom(String employeeId) {
    if (socket != null && isConnected) {
      socket?.emit('join_employee', employeeId);
      print('👤 Joined employee room: $employeeId');
    }
  }

  // Listen to location updates (Admin)
  void onLocationUpdate(Function(Map<String, dynamic>) callback) {
    socket?.on('location_updated', (data) {
      callback(data);
    });
  }

  // Send location update (Employee)
  void sendLocationUpdate(Map<String, dynamic> locationData) {
    if (socket != null && isConnected) {
      socket?.emit('location_update', locationData);
    }
  }

  // Disconnect
  void disconnect() {
    socket?.disconnect();
    socket?.dispose();
    isConnected = false;
  }
}
