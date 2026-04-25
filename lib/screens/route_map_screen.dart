import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../core/design/tokens.dart';
import '../models/route_stop.dart';
import '../providers/providers.dart';
import '../router/router.dart';
import 'route_map/widgets/widgets.dart';

/// Edge-to-edge map screen. Map fills the viewport; chrome is reduced
/// to a top bar with [CircleControl]s and a [SelectedStopSheet] that
/// slides in when a marker is tapped.
class RouteMapScreen extends ConsumerStatefulWidget {
  const RouteMapScreen({super.key});

  @override
  ConsumerState<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends ConsumerState<RouteMapScreen> {
  final MapController _mapController = MapController();
  String? _selectedStopId;

  @override
  Widget build(BuildContext context) {
    final routeState = ref.watch(routeProvider);
    final locationState = ref.watch(locationProvider);
    final stops = routeState.stops;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      // No SafeArea on the map layer — bleed under system chrome. The
      // floating controls re-add their own SafeArea.
      body: Stack(
        children: [
          if (stops.isEmpty)
            const RouteMapEmptyState()
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialCenter(stops, locationState),
                initialZoom: 13,
                onTap: (_, _) => setState(() => _selectedStopId = null),
              ),
              children: [
                // CARTO Dark tiles for the cockpit aesthetic, OSM as
                // fallback when the CARTO endpoint hiccups.
                TileLayer(
                  urlTemplate:
                      'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.betterroute.aea',
                  fallbackUrl:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                if (stops.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: stops
                            .map((s) => LatLng(s.latitude, s.longitude))
                            .toList(),
                        color: AppColors.fgPrimary.withValues(alpha: 0.5),
                        strokeWidth: 2.5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: stops.map(_buildMarker).toList(),
                ),
                if (locationState.currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(
                          locationState.currentLocation!.latitude,
                          locationState.currentLocation!.longitude,
                        ),
                        width: 44,
                        height: 44,
                        child: const PulsingDot(),
                      ),
                    ],
                  ),
              ],
            ),

          // Floating top controls.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  CircleControl(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                  const Spacer(),
                  if (stops.isNotEmpty) ...[
                    CircleControl(
                      icon: Icons.fit_screen_rounded,
                      onTap: () => _fitBounds(stops),
                    ),
                    const SizedBox(width: 8),
                    CircleControl(
                      icon: Icons.my_location_rounded,
                      onTap: () => _centerOnDriver(locationState),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Sliding bottom sheet for the selected stop.
          AnimatedPositioned(
            duration: AppMotion.standard,
            curve: AppMotion.emphasized,
            left: 0,
            right: 0,
            bottom: _selectedStopId == null ? -260 : 0,
            child: _selectedStopId == null
                ? const SizedBox.shrink()
                : SelectedStopSheet(
                    stop: stops.firstWhere(
                      (s) => s.id == _selectedStopId,
                      orElse: () => stops.first,
                    ),
                    onClose: () => setState(() => _selectedStopId = null),
                    onNavigate: (s) => ref
                        .read(locationProvider.notifier)
                        .navigateTo(s.latitude, s.longitude),
                    onDetails: (s) =>
                        context.push(AppRoutes.stopDetailPath(s.id)),
                  ),
          ),
        ],
      ),
    );
  }

  Marker _buildMarker(RouteStop stop) {
    final isSelected = _selectedStopId == stop.id;
    final color = _statusColor(stop.status);
    final size = isSelected ? 44.0 : 32.0;

    return Marker(
      point: LatLng(stop.latitude, stop.longitude),
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedStopId = stop.id);
          _mapController.move(
            LatLng(stop.latitude, stop.longitude),
            _mapController.camera.zoom < 14 ? 14 : _mapController.camera.zoom,
          );
        },
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standardCurve,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.bgBase, width: 2),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              stop.sequence.toString(),
              style: AppTypography.label.copyWith(
                color: stop.status == StopStatus.pending
                    ? AppColors.fgPrimary
                    : AppColors.fgInverse,
                fontSize: isSelected ? 14 : 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _fitBounds(List<RouteStop> stops) {
    if (stops.isEmpty) return;
    final points = stops.map((s) => LatLng(s.latitude, s.longitude)).toList();
    final locationState = ref.read(locationProvider);
    if (locationState.currentLocation != null) {
      points.add(LatLng(
        locationState.currentLocation!.latitude,
        locationState.currentLocation!.longitude,
      ));
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(64, 120, 64, 240),
      ),
    );
  }

  void _centerOnDriver(LocationState state) {
    if (state.currentLocation == null) return;
    _mapController.move(
      LatLng(state.currentLocation!.latitude, state.currentLocation!.longitude),
      16,
    );
  }

  LatLng _initialCenter(List<RouteStop> stops, LocationState location) {
    if (location.currentLocation != null) {
      return LatLng(
        location.currentLocation!.latitude,
        location.currentLocation!.longitude,
      );
    }
    if (stops.isNotEmpty) {
      return LatLng(stops.first.latitude, stops.first.longitude);
    }
    return const LatLng(-12.046374, -77.042793);
  }

  Color _statusColor(StopStatus s) {
    switch (s) {
      case StopStatus.completed:
        return AppColors.accentLive;
      case StopStatus.failed:
        return AppColors.accentDanger;
      case StopStatus.skipped:
        return AppColors.fgTertiary;
      case StopStatus.inProgress:
        return AppColors.accentLive;
      case StopStatus.pending:
        return AppColors.fgPrimary;
    }
  }
}
