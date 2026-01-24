import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/route_service.dart';
import '../services/api_service.dart';

/// Route state
class RouteState {
  final DriverRouteData? data;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final DateTime? lastUpdated;

  const RouteState({
    this.data,
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.lastUpdated,
  });

  bool get hasRoute => data?.hasRoute ?? false;
  List<RouteStop> get stops => data?.stops ?? [];
  RouteStop? get currentStop => data?.currentStop;
  DriverInfo? get driver => data?.driver;
  Vehicle? get vehicle => data?.vehicle;
  RouteMetrics? get metrics => data?.metrics;

  RouteState copyWith({
    DriverRouteData? data,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    DateTime? lastUpdated,
    bool clearError = false,
  }) {
    return RouteState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : (error ?? this.error),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Route notifier
class RouteNotifier extends StateNotifier<RouteState> {
  final RouteService _routeService;

  RouteNotifier(this._routeService) : super(const RouteState());

  /// Load driver's route
  Future<void> loadRoute({bool refresh = false}) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: !refresh,
      isRefreshing: refresh,
      clearError: true,
    );

    try {
      final data = await _routeService.getMyRoute();
      state = state.copyWith(
        data: data,
        isLoading: false,
        isRefreshing: false,
        lastUpdated: DateTime.now(),
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: 'Error al cargar la ruta',
      );
    }
  }

  /// Refresh route data
  Future<void> refresh() => loadRoute(refresh: true);

  /// Start a stop
  Future<bool> startStop(String stopId) async {
    try {
      await _routeService.startStop(stopId);
      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Complete a stop with evidence
  Future<bool> completeStop({
    required String stopId,
    required List<String> evidenceUrls,
    String? notes,
  }) async {
    try {
      await _routeService.completeStop(
        stopId: stopId,
        evidenceUrls: evidenceUrls,
        notes: notes,
      );
      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Fail a stop with reason
  Future<bool> failStop({
    required String stopId,
    required FailureReason reason,
    List<String>? evidenceUrls,
    String? notes,
  }) async {
    try {
      await _routeService.failStop(
        stopId: stopId,
        reason: reason,
        evidenceUrls: evidenceUrls,
        notes: notes,
      );
      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Skip a stop
  Future<bool> skipStop({
    required String stopId,
    String? notes,
  }) async {
    try {
      await _routeService.skipStop(
        stopId: stopId,
        notes: notes,
      );
      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Upload evidence photo
  Future<String?> uploadEvidence({
    required File photo,
    required String trackingId,
    int? index,
  }) async {
    try {
      return await _routeService.uploadEvidencePhoto(
        photo: photo,
        trackingId: trackingId,
        index: index,
      );
    } catch (e) {
      return null;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Clear data on logout
  void clear() {
    state = const RouteState();
  }
}

/// Route service provider
final routeServiceProvider = Provider<RouteService>((ref) {
  return RouteService();
});

/// Route state provider
final routeProvider = StateNotifierProvider<RouteNotifier, RouteState>((ref) {
  final routeService = ref.watch(routeServiceProvider);
  return RouteNotifier(routeService);
});

/// Convenience providers
final stopsProvider = Provider<List<RouteStop>>((ref) {
  return ref.watch(routeProvider).stops;
});

final currentStopProvider = Provider<RouteStop?>((ref) {
  return ref.watch(routeProvider).currentStop;
});

final driverInfoProvider = Provider<DriverInfo?>((ref) {
  return ref.watch(routeProvider).driver;
});

final vehicleProvider = Provider<Vehicle?>((ref) {
  return ref.watch(routeProvider).vehicle;
});

final routeMetricsProvider = Provider<RouteMetrics?>((ref) {
  return ref.watch(routeProvider).metrics;
});

/// Get a specific stop by ID
final stopByIdProvider = Provider.family<RouteStop?, String>((ref, stopId) {
  final stops = ref.watch(stopsProvider);
  return stops.cast<RouteStop?>().firstWhere(
        (s) => s?.id == stopId,
        orElse: () => null,
      );
});

/// Filter stops by status
final pendingStopsProvider = Provider<List<RouteStop>>((ref) {
  return ref.watch(stopsProvider).where((s) => s.status.isPending).toList();
});

final completedStopsProvider = Provider<List<RouteStop>>((ref) {
  return ref.watch(stopsProvider).where((s) => s.status.isCompleted).toList();
});

final failedStopsProvider = Provider<List<RouteStop>>((ref) {
  return ref.watch(stopsProvider).where((s) => s.status.isFailed).toList();
});
