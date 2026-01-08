// lib/services/socket_service.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  String? _lastToken;
  String? _lastRoom;

  IO.Socket? get socket => _socket;
  bool get isConnected => _isConnected;

  // Connect with auto-reconnect
  void connect(String token, {String? baseUrl}) {
    _lastToken = token;

    final url = baseUrl ?? 'https://vickey-neustic-avoidably.ngrok-free.dev';

    print('🔌 Connecting to Socket.IO: $url');

    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling']) // Fallback to polling
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(_maxReconnectAttempts)
          .setReconnectionDelay(2000) // 2 seconds
          .setReconnectionDelayMax(10000) // Max 10 seconds
          .setAuth({'token': token})
          .build(),
    );

    _setupListeners();
  }

  void _setupListeners() {
    _socket?.onConnect((_) {
      print('✅ Socket.io Connected');
      _isConnected = true;
      _reconnectAttempts = 0;
      _cancelReconnectTimer();

      // Rejoin room if we were in one
      if (_lastRoom != null) {
        print('🔄 Re-joining room: $_lastRoom');
        _socket?.emit('join_room', _lastRoom);
      }
    });

    _socket?.onDisconnect((_) {
      print('❌ Socket.io Disconnected');
      _isConnected = false;
      _attemptReconnect();
    });

    _socket?.onConnectError((error) {
      print('❌ Socket.io Connection Error: $error');
      _isConnected = false;
      _attemptReconnect();
    });

    _socket?.onError((error) {
      print('❌ Socket.io Error: $error');
    });

    _socket?.on('reconnect', (data) {
      print('🔄 Socket.io Reconnected (attempt ${data})');
      _reconnectAttempts = 0;
    });

    _socket?.on('reconnect_attempt', (attempt) {
      print('🔄 Reconnection attempt $attempt...');
    });

    _socket?.on('reconnect_failed', (_) {
      print(
          '❌ Socket.io Reconnection failed after $_maxReconnectAttempts attempts');
      _scheduleManualReconnect();
    });

    _socket?.connect();
  }

  // Manual reconnect with exponential backoff
  void _attemptReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print(
          '⚠️ Max reconnection attempts reached, scheduling delayed retry...');
      _scheduleManualReconnect();
      return;
    }

    _reconnectAttempts++;
    final delay =
        Duration(seconds: 2 * _reconnectAttempts); // Exponential backoff

    print(
        '🔄 Will attempt manual reconnect in ${delay.inSeconds}s (attempt $_reconnectAttempts)');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!_isConnected && _lastToken != null) {
        print('🔄 Attempting manual reconnection...');
        disconnect();
        connect(_lastToken!);
      }
    });
  }

  void _scheduleManualReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(minutes: 1), () {
      if (!_isConnected && _lastToken != null) {
        print('🔄 Retrying connection after cooldown...');
        _reconnectAttempts = 0;
        disconnect();
        connect(_lastToken!);
      }
    });
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  // Join rooms
  void joinEmployeeRoom(String employeeId) {
    _lastRoom = 'employee_$employeeId';
    if (_isConnected) {
      _socket?.emit('join_room', _lastRoom);
      print('👤 Joined employee room: $_lastRoom');
    }
  }

  void joinAdminRoom() {
    _lastRoom = 'admin';
    if (_isConnected) {
      _socket?.emit('join_room', _lastRoom);
      print('👨‍💼 Joined admin room');
    }
  }

  // Send location update
  void sendLocationUpdate(Map<String, dynamic> data) {
    if (_isConnected) {
      _socket?.emit('location_update', data);
      print('📡 Location update sent via Socket.IO');
    } else {
      print('⚠️ Socket not connected, location update not sent');
    }
  }

  // Force reconnect
  void forceReconnect() {
    print('🔄 Forcing reconnection...');
    disconnect();
    if (_lastToken != null) {
      connect(_lastToken!);
    }
  }

  // Disconnect
  void disconnect() {
    print('🔌 Disconnecting Socket.IO...');
    _cancelReconnectTimer();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _lastRoom = null;
  }

  // Cleanup
  void dispose() {
    disconnect();
  }
}
