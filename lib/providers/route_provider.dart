import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/route_service.dart';
import '../services/api_service.dart';
import '../services/offline_outbox.dart';
import '../services/tracking_service.dart';

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
  final TrackingService _trackingService = TrackingService();

  RouteNotifier(this._routeService) : super(const RouteState());

  /// Push the active route context into TrackingService so location pings
  /// carry stopSequence/jobId/routeId. Called after every route load and
  /// after every status change that may shift the "current stop".
  void _syncTrackingContext(DriverRouteData? data) {
    final route = data?.route;
    final current = data?.currentStop;
    _trackingService.setActiveStopContext(
      stopSequence: current?.sequence,
      jobId: route?.jobId,
      routeId: route?.id,
    );
  }

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
      _syncTrackingContext(data);
      // We have connectivity — drain any closes queued from a no-signal zone.
      OfflineOutbox().flush();
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

  /// Complete a stop with evidence. [gpsLatitude]/[gpsLongitude] are the
  /// device position captured at closing time (audit trail), absent when
  /// no GPS fix is available.
  Future<bool> completeStop({
    required String stopId,
    required List<String> evidenceUrls,
    String? notes,
    String? gpsLatitude,
    String? gpsLongitude,
    Map<String, dynamic>? customFields,
  }) async {
    try {
      await _routeService.completeStop(
        stopId: stopId,
        evidenceUrls: evidenceUrls,
        notes: notes,
        gpsLatitude: gpsLatitude,
        gpsLongitude: gpsLongitude,
        customFields: customFields,
      );
      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Fail a stop with reason. [reason] is the verbatim per-company policy
  /// string the driver selected. [gpsLatitude]/[gpsLongitude] are the
  /// device position captured at closing time (audit trail).
  Future<bool> failStop({
    required String stopId,
    required String reason,
    List<String>? evidenceUrls,
    String? notes,
    String? gpsLatitude,
    String? gpsLongitude,
  }) async {
    try {
      await _routeService.failStop(
        stopId: stopId,
        reason: reason,
        evidenceUrls: evidenceUrls,
        notes: notes,
        gpsLatitude: gpsLatitude,
        gpsLongitude: gpsLongitude,
      );
      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Transition a stop to a new workflow state. [workflowStateId] is kept
  /// in the signature for callers that still pass the target state id, but
  /// the backend crystallized its state machine and now derives everything
  /// from [systemState] alone — only the resulting status is sent.
  Future<bool> transitionStop({
    required String stopId,
    required String workflowStateId,
    required String systemState,
    String? notes,
    String? failureReason,
    List<String>? evidenceUrls,
  }) async {
    try {
      final status = StopStatus.fromString(systemState);
      await _routeService.updateStopStatus(
        stopId: stopId,
        status: status,
        notes: notes,
        failureReason: failureReason,
        evidenceUrls: evidenceUrls,
      );
      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Upload evidence photo. Lets exceptions propagate so callers can
  /// abort the completion flow when the upload fails — silently
  /// returning `null` was the bug that let drivers mark stops
  /// COMPLETED with `evidenceUrls = NULL` because every failed
  /// upload was indistinguishable from "no photo taken".
  Future<String> uploadEvidence({
    required File photo,
    required String trackingId,
    int? index,
  }) async {
    return await _routeService.uploadEvidencePhoto(
      photo: photo,
      trackingId: trackingId,
      index: index,
    );
  }

  /// Optimistically reflect a close that was queued offline, so the UI shows
  /// the stop as done immediately. The real sync happens through the outbox;
  /// the next successful route load replaces this with server truth.
  void applyLocalClose({
    required String stopId,
    required StopStatus status,
    String? failureReason,
    String? notes,
    List<String>? evidenceUrls,
    Map<String, dynamic>? customFields,
  }) {
    final data = state.data;
    final route = data?.route;
    if (data == null || route == null) return;
    final now = DateTime.now();
    final updatedStops = route.stops
        .map(
          (s) => s.id == stopId
              ? s.copyWith(
                  status: status,
                  completedAt: now,
                  failureReason: failureReason,
                  notes: notes,
                  evidenceUrls: evidenceUrls,
                  customFields: customFields,
                )
              : s,
        )
        .toList();
    state = state.copyWith(
      data: DriverRouteData(
        driver: data.driver,
        vehicle: data.vehicle,
        route: RouteInfo(
          id: route.id,
          jobId: route.jobId,
          jobCreatedAt: route.jobCreatedAt,
          stops: updatedStops,
        ),
        metrics: data.metrics,
      ),
    );
    _syncTrackingContext(state.data);
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
