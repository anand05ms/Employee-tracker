// lib/services/offline_queue_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';

class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  final ApiService _apiService = ApiService();
  final List<Map<String, dynamic>> _queue = [];
  Timer? _processTimer;
  bool _isProcessing = false;
  static const String _queueKey = 'offline_location_queue';
  static const int _maxQueueSize = 100;

  // Initialize and load persisted queue
  Future<void> initialize() async {
    await _loadQueue();
    _startProcessing();
    _listenToConnectivity();
  }

  // Add location update to queue
  Future<void> addLocationUpdate(double lat, double lng, String address) async {
    final update = {
      'latitude': lat,
      'longitude': lng,
      'address': address,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _queue.add(update);
    print('📥 Added to offline queue (${_queue.length} pending)');

    // Limit queue size
    if (_queue.length > _maxQueueSize) {
      _queue.removeAt(0);
      print('⚠️ Queue size limit reached, removed oldest update');
    }

    await _persistQueue();

    // Try to process immediately if online
    _processQueue();
  }

  // Load queue from persistent storage
  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);

      if (queueJson != null) {
        final List<dynamic> decoded = jsonDecode(queueJson);
        _queue.clear();
        _queue
            .addAll(decoded.map((e) => Map<String, dynamic>.from(e)).toList());
        print('📂 Loaded ${_queue.length} queued updates from storage');
      }
    } catch (e) {
      print('❌ Error loading queue: $e');
    }
  }

  // Persist queue to storage
  Future<void> _persistQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = jsonEncode(_queue);
      await prefs.setString(_queueKey, queueJson);
    } catch (e) {
      print('❌ Error persisting queue: $e');
    }
  }

  // Start periodic processing
  void _startProcessing() {
    _processTimer?.cancel();
    _processTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _processQueue();
    });
  }

  // Listen to connectivity changes
  void _listenToConnectivity() {
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        print('🌐 Connectivity restored, processing queue...');
        _processQueue();
      }
    });
  }

  // Process queued updates
  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;
    print('🔄 Processing ${_queue.length} queued updates...');

    final successful = <Map<String, dynamic>>[];

    for (var update in List.from(_queue)) {
      try {
        final response = await _apiService.updateLocation(
          update['latitude'],
          update['longitude'],
          update['address'],
        );

        if (response['success']) {
          successful.add(update);
          print('✅ Queued update sent successfully');
        }
      } catch (e) {
        print('❌ Failed to send queued update: $e');
        break; // Stop processing if network is down
      }

      // Small delay to avoid overwhelming server
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Remove successful updates
    for (var update in successful) {
      _queue.remove(update);
    }

    if (successful.isNotEmpty) {
      await _persistQueue();
      print(
          '✅ Processed ${successful.length} queued updates (${_queue.length} remaining)');
    }

    _isProcessing = false;
  }

  // Clear queue
  Future<void> clearQueue() async {
    _queue.clear();
    await _persistQueue();
    print('🗑️ Queue cleared');
  }

  // Get queue status
  int get queueSize => _queue.length;
  bool get hasQueuedUpdates => _queue.isNotEmpty;

  // Dispose
  void dispose() {
    _processTimer?.cancel();
  }
}
