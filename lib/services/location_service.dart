import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Location data wrapper
class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed;
  final DateTime timestamp;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.timestamp,
  });

  factory LocationData.fromPosition(Position position) {
    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      speed: position.speed,
      timestamp: position.timestamp,
    );
  }
}

/// Location service for GPS tracking and navigation
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionSubscription;
  final _locationController = StreamController<LocationData>.broadcast();

  Stream<LocationData> get locationStream => _locationController.stream;
  LocationData? _lastLocation;
  LocationData? get lastLocation => _lastLocation;

  bool _isTracking = false;
  bool get isTracking => _isTracking;

  /// Location settings optimized for delivery tracking
  static const LocationSettings _trackingSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 20, // Update every 20 meters
  );

  /// Check and request location permission
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Get current location once
  Future<LocationData?> getCurrentLocation() async {
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: _trackingSettings,
      );

      _lastLocation = LocationData.fromPosition(position);
      return _lastLocation;
    } catch (e) {
      return null;
    }
  }

  /// Start continuous location tracking
  Future<bool> startTracking() async {
    if (_isTracking) return true;

    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) return false;

    _isTracking = true;

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _trackingSettings,
    ).listen(
      (position) {
        _lastLocation = LocationData.fromPosition(position);
        _locationController.add(_lastLocation!);
      },
      onError: (error) {
        // Continue tracking despite errors
      },
    );

    return true;
  }

  /// Stop location tracking
  void stopTracking() {
    _isTracking = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Calculate distance between two points in meters
  double distanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Check if we're near a point
  bool isNearPoint(
    double pointLat,
    double pointLng, {
    double radiusMeters = 100,
  }) {
    if (_lastLocation == null) return false;

    final distance = distanceBetween(
      _lastLocation!.latitude,
      _lastLocation!.longitude,
      pointLat,
      pointLng,
    );

    return distance <= radiusMeters;
  }

  /// Get distance from current location to a point
  double? distanceToPoint(double lat, double lng) {
    if (_lastLocation == null) return null;
    return distanceBetween(
      _lastLocation!.latitude,
      _lastLocation!.longitude,
      lat,
      lng,
    );
  }

  /// Format distance for display
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toInt()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  /// Open navigation to coordinates
  Future<bool> navigateTo(double latitude, double longitude) async {
    // Try Google Maps first
    final googleMapsUrl = Uri.parse(
      'google.navigation:q=$latitude,$longitude&mode=d',
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      return launchUrl(googleMapsUrl);
    }

    // Fallback to web Google Maps
    final webUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving',
    );

    return launchUrl(webUrl, mode: LaunchMode.externalApplication);
  }

  /// Open navigation to address
  Future<bool> navigateToAddress(String address) async {
    final encodedAddress = Uri.encodeComponent(address);

    // Try Google Maps with address
    final googleMapsUrl = Uri.parse(
      'google.navigation:q=$encodedAddress&mode=d',
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      return launchUrl(googleMapsUrl);
    }

    // Fallback to web
    final webUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$encodedAddress&travelmode=driving',
    );

    return launchUrl(webUrl, mode: LaunchMode.externalApplication);
  }

  /// Open Waze navigation
  Future<bool> openWaze(double latitude, double longitude) async {
    final wazeUrl = Uri.parse(
      'https://waze.com/ul?ll=$latitude,$longitude&navigate=yes',
    );

    return launchUrl(wazeUrl, mode: LaunchMode.externalApplication);
  }

  /// Dispose resources
  void dispose() {
    stopTracking();
    _locationController.close();
  }
}
