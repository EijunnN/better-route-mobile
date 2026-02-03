import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tracking_service.dart';

/// Tracking state
class TrackingState {
  final bool isTracking;
  final int successfulSends;
  final int failedSends;
  final int pendingLocations;
  final DateTime? lastSendTime;
  final String? lastError;

  const TrackingState({
    this.isTracking = false,
    this.successfulSends = 0,
    this.failedSends = 0,
    this.pendingLocations = 0,
    this.lastSendTime,
    this.lastError,
  });

  TrackingState copyWith({
    bool? isTracking,
    int? successfulSends,
    int? failedSends,
    int? pendingLocations,
    DateTime? lastSendTime,
    String? lastError,
    bool clearError = false,
  }) {
    return TrackingState(
      isTracking: isTracking ?? this.isTracking,
      successfulSends: successfulSends ?? this.successfulSends,
      failedSends: failedSends ?? this.failedSends,
      pendingLocations: pendingLocations ?? this.pendingLocations,
      lastSendTime: lastSendTime ?? this.lastSendTime,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  factory TrackingState.fromStats(Map<String, dynamic> stats) {
    return TrackingState(
      isTracking: stats['isTracking'] as bool? ?? false,
      successfulSends: stats['successfulSends'] as int? ?? 0,
      failedSends: stats['failedSends'] as int? ?? 0,
      pendingLocations: stats['pendingLocations'] as int? ?? 0,
      lastSendTime: stats['lastSendTime'] != null
          ? DateTime.tryParse(stats['lastSendTime'] as String)
          : null,
      lastError: stats['lastError'] as String?,
    );
  }
}

/// Tracking notifier
class TrackingNotifier extends StateNotifier<TrackingState> {
  final TrackingService _trackingService;

  TrackingNotifier(this._trackingService) : super(const TrackingState());

  /// Start tracking and sending location to server
  Future<bool> startTracking() async {
    final started = await _trackingService.startTracking();
    _updateState();
    return started;
  }

  /// Stop tracking
  void stopTracking() {
    _trackingService.stopTracking();
    _updateState();
  }

  /// Force send current location
  Future<bool> forceSendLocation() async {
    final success = await _trackingService.forceSendLocation();
    _updateState();
    return success;
  }

  /// Update state from service
  void _updateState() {
    final stats = _trackingService.getStats();
    state = TrackingState.fromStats(stats);
  }

  /// Refresh state
  void refresh() {
    _updateState();
  }

  /// Reset statistics
  void resetStats() {
    _trackingService.resetStats();
    _updateState();
  }

  @override
  void dispose() {
    _trackingService.dispose();
    super.dispose();
  }
}

/// Tracking service provider
final trackingServiceProvider = Provider<TrackingService>((ref) {
  return TrackingService();
});

/// Tracking state provider
final trackingProvider =
    StateNotifierProvider<TrackingNotifier, TrackingState>((ref) {
  final trackingService = ref.watch(trackingServiceProvider);
  return TrackingNotifier(trackingService);
});

/// Is server tracking active provider
final isServerTrackingProvider = Provider<bool>((ref) {
  return ref.watch(trackingProvider).isTracking;
});

/// Tracking stats provider
final trackingStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final state = ref.watch(trackingProvider);
  return {
    'successfulSends': state.successfulSends,
    'failedSends': state.failedSends,
    'pendingLocations': state.pendingLocations,
    'lastSendTime': state.lastSendTime?.toIso8601String(),
    'lastError': state.lastError,
  };
});
