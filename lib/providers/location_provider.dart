import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/location_service.dart';

/// Location state
class LocationState {
  final LocationData? currentLocation;
  final bool isTracking;
  final bool hasPermission;
  final String? error;

  const LocationState({
    this.currentLocation,
    this.isTracking = false,
    this.hasPermission = false,
    this.error,
  });

  LocationState copyWith({
    LocationData? currentLocation,
    bool? isTracking,
    bool? hasPermission,
    String? error,
    bool clearError = false,
  }) {
    return LocationState(
      currentLocation: currentLocation ?? this.currentLocation,
      isTracking: isTracking ?? this.isTracking,
      hasPermission: hasPermission ?? this.hasPermission,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Location notifier
class LocationNotifier extends StateNotifier<LocationState> {
  final LocationService _locationService;
  StreamSubscription<LocationData>? _subscription;

  LocationNotifier(this._locationService) : super(const LocationState());

  /// Check and request permission
  Future<bool> checkPermission() async {
    final hasPermission = await _locationService.checkAndRequestPermission();
    state = state.copyWith(hasPermission: hasPermission);
    return hasPermission;
  }

  /// Get current location once
  Future<LocationData?> getCurrentLocation() async {
    try {
      final location = await _locationService.getCurrentLocation();
      if (location != null) {
        state = state.copyWith(
          currentLocation: location,
          hasPermission: true,
        );
      }
      return location;
    } catch (e) {
      state = state.copyWith(error: 'Error al obtener ubicacion');
      return null;
    }
  }

  /// Start continuous tracking
  Future<bool> startTracking() async {
    if (state.isTracking) return true;

    final started = await _locationService.startTracking();
    if (started) {
      state = state.copyWith(isTracking: true, hasPermission: true);

      _subscription = _locationService.locationStream.listen((location) {
        state = state.copyWith(currentLocation: location);
      });

      // Get initial location
      await getCurrentLocation();
    } else {
      state = state.copyWith(
        error: 'No se pudo iniciar el seguimiento GPS',
      );
    }

    return started;
  }

  /// Stop tracking
  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
    _locationService.stopTracking();
    state = state.copyWith(isTracking: false);
  }

  /// Calculate distance to a point
  double? distanceTo(double lat, double lng) {
    return _locationService.distanceToPoint(lat, lng);
  }

  /// Format distance for display
  String formatDistance(double meters) {
    return _locationService.formatDistance(meters);
  }

  /// Navigate to coordinates
  Future<bool> navigateTo(double lat, double lng) {
    return _locationService.navigateTo(lat, lng);
  }

  /// Navigate to address
  Future<bool> navigateToAddress(String address) {
    return _locationService.navigateToAddress(address);
  }

  /// Open Waze
  Future<bool> openWaze(double lat, double lng) {
    return _locationService.openWaze(lat, lng);
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}

/// Location service provider
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Location state provider
final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return LocationNotifier(locationService);
});

/// Current location provider
final currentLocationProvider = Provider<LocationData?>((ref) {
  return ref.watch(locationProvider).currentLocation;
});

/// Is tracking provider
final isTrackingProvider = Provider<bool>((ref) {
  return ref.watch(locationProvider).isTracking;
});

/// Distance to stop provider
final distanceToStopProvider =
    Provider.family<double?, ({double lat, double lng})>((ref, coords) {
  final location = ref.watch(currentLocationProvider);
  if (location == null) return null;

  final locationService = ref.read(locationServiceProvider);
  return locationService.distanceBetween(
    location.latitude,
    location.longitude,
    coords.lat,
    coords.lng,
  );
});
