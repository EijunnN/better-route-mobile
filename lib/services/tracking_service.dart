import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import '../core/constants.dart';
import 'api_service.dart';
import 'location_service.dart';

/// Service for sending driver location to the server
class TrackingService {
  static final TrackingService _instance = TrackingService._internal();
  factory TrackingService() => _instance;
  TrackingService._internal();

  final LocationService _locationService = LocationService();
  final ApiService _api = ApiService();
  final Battery _battery = Battery();

  Timer? _trackingTimer;
  StreamSubscription<LocationData>? _locationSubscription;
  bool _isTracking = false;
  bool get isTracking => _isTracking;

  // Tracking statistics
  int _successfulSends = 0;
  int _failedSends = 0;
  DateTime? _lastSendTime;
  String? _lastError;

  int get successfulSends => _successfulSends;
  int get failedSends => _failedSends;
  DateTime? get lastSendTime => _lastSendTime;
  String? get lastError => _lastError;

  // Queue for offline locations
  final List<Map<String, dynamic>> _pendingLocations = [];
  static const int _maxPendingLocations = 100;

  /// Start tracking and sending location to server
  Future<bool> startTracking() async {
    if (_isTracking) return true;

    // First, ensure location tracking is started
    final locationStarted = await _locationService.startTracking();
    if (!locationStarted) {
      _lastError = 'No se pudo iniciar el GPS';
      return false;
    }

    _isTracking = true;
    _lastError = null;

    // Listen to location updates
    _locationSubscription = _locationService.locationStream.listen(
      (location) {
        // Location updates are handled by the timer
        // This ensures we don't send too frequently
      },
    );

    // Start periodic sending
    _trackingTimer = Timer.periodic(
      Duration(seconds: AppConstants.trackingIntervalSeconds),
      (_) => _sendCurrentLocation(),
    );

    // Send initial location immediately
    await _sendCurrentLocation();

    return true;
  }

  /// Stop tracking
  void stopTracking() {
    _isTracking = false;
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _locationService.stopTracking();
  }

  /// Send current location to server
  Future<void> _sendCurrentLocation() async {
    if (!_isTracking) return;

    final location = _locationService.lastLocation;
    if (location == null) {
      _lastError = 'Sin ubicación GPS';
      return;
    }

    // Get battery level
    int? batteryLevel;
    try {
      batteryLevel = await _battery.batteryLevel;
    } catch (_) {
      // Ignore battery errors
    }

    final locationData = {
      'latitude': location.latitude,
      'longitude': location.longitude,
      'accuracy': location.accuracy.round(),
      'speed': (location.speed * 3.6).round(), // Convert m/s to km/h
      'recordedAt': DateTime.now().toUtc().toIso8601String(),
      'source': 'GPS',
      if (batteryLevel != null) 'batteryLevel': batteryLevel,
    };

    // Try to send with retry logic
    bool success = await _sendLocationWithRetry(locationData);

    if (success) {
      _successfulSends++;
      _lastSendTime = DateTime.now();
      _lastError = null;

      // Try to send pending locations
      await _sendPendingLocations();
    } else {
      _failedSends++;
      // Queue for later if failed
      _queueLocation(locationData);
    }
  }

  /// Send location with retry logic
  Future<bool> _sendLocationWithRetry(Map<String, dynamic> data) async {
    for (int attempt = 0; attempt < AppConstants.trackingRetryAttempts; attempt++) {
      try {
        final response = await _api.post(
          ApiConfig.locationEndpoint,
          data: data,
        );

        if (response.statusCode == 201) {
          return true;
        }
      } catch (e) {
        _lastError = e.toString();

        // Wait before retry (except on last attempt)
        if (attempt < AppConstants.trackingRetryAttempts - 1) {
          await Future.delayed(
            Duration(seconds: AppConstants.trackingRetryDelaySeconds),
          );
        }
      }
    }

    return false;
  }

  /// Queue location for later sending
  void _queueLocation(Map<String, dynamic> data) {
    if (_pendingLocations.length >= _maxPendingLocations) {
      // Remove oldest location
      _pendingLocations.removeAt(0);
    }
    _pendingLocations.add(data);
  }

  /// Send pending locations when connection is restored
  Future<void> _sendPendingLocations() async {
    if (_pendingLocations.isEmpty) return;

    final toSend = List<Map<String, dynamic>>.from(_pendingLocations);
    _pendingLocations.clear();

    for (final location in toSend) {
      try {
        await _api.post(
          ApiConfig.locationEndpoint,
          data: location,
        );
      } catch (_) {
        // Re-queue failed locations
        _pendingLocations.add(location);
      }
    }
  }

  /// Force send current location (e.g., when starting/completing a stop)
  Future<bool> forceSendLocation() async {
    final location = _locationService.lastLocation;
    if (location == null) {
      // Try to get current location
      await _locationService.getCurrentLocation();
    }

    if (_locationService.lastLocation == null) {
      return false;
    }

    int? batteryLevel;
    try {
      batteryLevel = await _battery.batteryLevel;
    } catch (_) {}

    final locationData = {
      'latitude': _locationService.lastLocation!.latitude,
      'longitude': _locationService.lastLocation!.longitude,
      'accuracy': _locationService.lastLocation!.accuracy.round(),
      'speed': (_locationService.lastLocation!.speed * 3.6).round(),
      'recordedAt': DateTime.now().toUtc().toIso8601String(),
      'source': 'GPS',
      if (batteryLevel != null) 'batteryLevel': batteryLevel,
    };

    return await _sendLocationWithRetry(locationData);
  }

  /// Get tracking statistics
  Map<String, dynamic> getStats() {
    return {
      'isTracking': _isTracking,
      'successfulSends': _successfulSends,
      'failedSends': _failedSends,
      'pendingLocations': _pendingLocations.length,
      'lastSendTime': _lastSendTime?.toIso8601String(),
      'lastError': _lastError,
    };
  }

  /// Reset statistics
  void resetStats() {
    _successfulSends = 0;
    _failedSends = 0;
    _lastSendTime = null;
    _lastError = null;
  }

  /// Dispose resources
  void dispose() {
    stopTracking();
    _pendingLocations.clear();
  }
}
