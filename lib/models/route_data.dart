import 'driver_info.dart';
import 'vehicle.dart';
import 'route_stop.dart';

/// Route metrics from backend
class RouteMetrics {
  final int totalStops;
  final int completedStops;
  final int pendingStops;
  final int inProgressStops;
  final int failedStops;
  final int skippedStops;
  final int progressPercentage;
  final double totalDistance;
  final double totalDuration;
  final double totalWeight;
  final double totalVolume;
  final double totalValue;
  final int totalUnits;

  const RouteMetrics({
    required this.totalStops,
    required this.completedStops,
    required this.pendingStops,
    required this.inProgressStops,
    required this.failedStops,
    required this.skippedStops,
    required this.progressPercentage,
    required this.totalDistance,
    required this.totalDuration,
    required this.totalWeight,
    required this.totalVolume,
    required this.totalValue,
    required this.totalUnits,
  });

  factory RouteMetrics.fromJson(Map<String, dynamic> json) {
    return RouteMetrics(
      totalStops: json['totalStops'] as int? ?? 0,
      completedStops: json['completedStops'] as int? ?? 0,
      pendingStops: json['pendingStops'] as int? ?? 0,
      inProgressStops: json['inProgressStops'] as int? ?? 0,
      failedStops: json['failedStops'] as int? ?? 0,
      skippedStops: json['skippedStops'] as int? ?? 0,
      progressPercentage: json['progressPercentage'] as int? ?? 0,
      totalDistance: (json['totalDistance'] as num?)?.toDouble() ?? 0,
      totalDuration: (json['totalDuration'] as num?)?.toDouble() ?? 0,
      totalWeight: (json['totalWeight'] as num?)?.toDouble() ?? 0,
      totalVolume: (json['totalVolume'] as num?)?.toDouble() ?? 0,
      totalValue: (json['totalValue'] as num?)?.toDouble() ?? 0,
      totalUnits: json['totalUnits'] as int? ?? 0,
    );
  }

  factory RouteMetrics.empty() => const RouteMetrics(
        totalStops: 0,
        completedStops: 0,
        pendingStops: 0,
        inProgressStops: 0,
        failedStops: 0,
        skippedStops: 0,
        progressPercentage: 0,
        totalDistance: 0,
        totalDuration: 0,
        totalWeight: 0,
        totalVolume: 0,
        totalValue: 0,
        totalUnits: 0,
      );

  double get progress => totalStops > 0 ? completedStops / totalStops : 0;

  String get distanceDisplay {
    if (totalDistance < 1000) {
      return '${totalDistance.toInt()} m';
    }
    return '${(totalDistance / 1000).toStringAsFixed(1)} km';
  }

  String get durationDisplay {
    final minutes = (totalDuration / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }
}

/// Route information from backend
class RouteInfo {
  final String id;
  final String jobId;
  final DateTime jobCreatedAt;
  final List<RouteStop> stops;

  const RouteInfo({
    required this.id,
    required this.jobId,
    required this.jobCreatedAt,
    required this.stops,
  });

  factory RouteInfo.fromJson(Map<String, dynamic> json) {
    return RouteInfo(
      id: json['id'] as String,
      jobId: json['jobId'] as String,
      jobCreatedAt: DateTime.parse(json['jobCreatedAt'] as String),
      stops: (json['stops'] as List)
          .map((s) => RouteStop.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Get the next pending or in-progress stop
  RouteStop? get currentStop {
    // First look for in-progress
    for (final stop in stops) {
      if (stop.status.isInProgress) return stop;
    }
    // Then look for first pending
    for (final stop in stops) {
      if (stop.status.isPending) return stop;
    }
    return null;
  }

  /// Get stops by status
  List<RouteStop> stopsByStatus(StopStatus status) {
    return stops.where((s) => s.status == status).toList();
  }
}

/// Complete driver route data from /api/mobile/driver/my-route
class DriverRouteData {
  final DriverInfo driver;
  final Vehicle? vehicle;
  final RouteInfo? route;
  final RouteMetrics? metrics;

  const DriverRouteData({
    required this.driver,
    this.vehicle,
    this.route,
    this.metrics,
  });

  factory DriverRouteData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return DriverRouteData(
      driver: DriverInfo.fromJson(data['driver'] as Map<String, dynamic>),
      vehicle: data['vehicle'] != null
          ? Vehicle.fromJson(data['vehicle'] as Map<String, dynamic>)
          : null,
      route: data['route'] != null
          ? RouteInfo.fromJson(data['route'] as Map<String, dynamic>)
          : null,
      metrics: data['metrics'] != null
          ? RouteMetrics.fromJson(data['metrics'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get hasRoute => route != null && route!.stops.isNotEmpty;

  List<RouteStop> get stops => route?.stops ?? [];

  RouteStop? get currentStop => route?.currentStop;
}
