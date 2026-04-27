import 'dart:async';
import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';

/// Outcome of a permission request. The caller distinguishes "tracking
/// is fully usable in background" from "tracking will die the moment
/// the app is minimized" so the UI can prompt the driver to upgrade.
enum LocationPermissionStatus {
  /// Device GPS is off entirely — user must enable it from system settings.
  serviceDisabled,
  /// User refused at the prompt. Recoverable: ask again.
  denied,
  /// User refused with "don't ask again" (Android) or denied (iOS).
  /// Only Settings can fix this.
  deniedForever,
  /// Foreground only. The route notification will keep tracking alive
  /// while the screen is on, but minimizing the app or locking the
  /// screen will stop emissions.
  foregroundOnly,
  /// Background-capable — the foreground service can keep emitting
  /// when the driver minimizes the app or locks the screen. This is
  /// what we need for a delivery route.
  background,
}

/// Location data wrapper
class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed; // meters/second from Geolocator
  /// Bearing/heading in degrees (0-360). The backend persists it on
  /// `driver_locations.heading` and the monitoring map uses it to render the
  /// directional arrow on the driver marker.
  final double heading;
  /// Altitude in meters. Geolocator returns 0 when unavailable; the backend
  /// accepts null/0 indistinctly.
  final double altitude;
  final DateTime timestamp;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.heading,
    required this.altitude,
    required this.timestamp,
  });

  factory LocationData.fromPosition(Position position) {
    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      speed: position.speed,
      heading: position.heading,
      altitude: position.altitude,
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

  LocationPermissionStatus _lastPermissionStatus = LocationPermissionStatus.denied;
  LocationPermissionStatus get lastPermissionStatus => _lastPermissionStatus;

  /// Platform-aware tracking settings. The foreground notification on
  /// Android is what makes background location *legal* on Android 10+ —
  /// without it the OS throttles the app to a few pings/hour. On iOS,
  /// `allowBackgroundLocationUpdates` plus `UIBackgroundModes: location`
  /// in Info.plist keeps the position stream alive when the app is in
  /// background. Distance filter of 25m kills redundant pings when the
  /// driver is parked at a customer (GPS noise still emits points).
  static LocationSettings get _trackingSettings {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: AppConstants.trackingDistanceFilterMeters,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Seguimiento de ruta activo',
          notificationText: 'Tu ubicación se está enviando para monitorear la entrega.',
          notificationChannelName: 'Tracking de ruta',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: AppConstants.trackingDistanceFilterMeters,
        activityType: ActivityType.automotiveNavigation,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: AppConstants.trackingDistanceFilterMeters,
    );
  }

  /// Run the full permission flow and return the resulting status.
  ///
  /// Android 11+ does not allow asking for `ACCESS_BACKGROUND_LOCATION`
  /// in the same dialog as foreground — the OS forces a two-step flow:
  /// first prompt for `whileInUse`, then a separate prompt (which
  /// usually opens system settings) to upgrade to `always`. iOS handles
  /// the upgrade automatically the first time the app reads location
  /// in background, so a second call there is a no-op.
  Future<LocationPermissionStatus> requestPermissionStatus() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return _lastPermissionStatus = LocationPermissionStatus.serviceDisabled;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return _lastPermissionStatus = LocationPermissionStatus.denied;
    }
    if (permission == LocationPermission.deniedForever) {
      return _lastPermissionStatus = LocationPermissionStatus.deniedForever;
    }

    if (permission == LocationPermission.whileInUse && Platform.isAndroid) {
      final upgraded = await Geolocator.requestPermission();
      if (upgraded == LocationPermission.always) {
        return _lastPermissionStatus = LocationPermissionStatus.background;
      }
      return _lastPermissionStatus = LocationPermissionStatus.foregroundOnly;
    }

    return _lastPermissionStatus = (permission == LocationPermission.always)
        ? LocationPermissionStatus.background
        : LocationPermissionStatus.foregroundOnly;
  }

  /// Boolean shim used by callers that only care whether *some* level
  /// of location access was granted. Prefer [requestPermissionStatus]
  /// when the caller can react differently to background vs foreground.
  Future<bool> checkAndRequestPermission() async {
    final status = await requestPermissionStatus();
    return status == LocationPermissionStatus.background ||
        status == LocationPermissionStatus.foregroundOnly;
  }

  /// Open the app's settings page so the driver can manually upgrade
  /// to "always" or undo "don't ask again". Returns true if the page
  /// was opened.
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  /// Open the device location settings (for serviceDisabled recovery).
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// Get current location once
  Future<LocationData?> getCurrentLocation() async {
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
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
