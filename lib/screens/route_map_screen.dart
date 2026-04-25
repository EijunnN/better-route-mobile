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
import '../widgets/app/app.dart';

/// Edge-to-edge map screen. The map fills the entire viewport, chrome is
/// reduced to a floating top bar (back + recenter) and a draggable bottom
/// sheet that holds stop details when one is selected.
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
      // No SafeArea here on purpose — map should bleed under the system
      // chrome. We re-add SafeArea around the floating controls.
      body: Stack(
        children: [
          // Map layer.
          if (stops.isEmpty)
            const _EmptyState()
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialCenter(stops, locationState),
                initialZoom: 13,
                onTap: (_, _) => setState(() => _selectedStopId = null),
              ),
              children: [
                // Dark tile layer — using CARTO Dark Matter for premium
                // mood matching the cockpit theme. Falls back to OSM
                // copyright on tile-server outage.
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
                      _buildDriverMarker(
                        locationState.currentLocation!.latitude,
                        locationState.currentLocation!.longitude,
                      ),
                    ],
                  ),
              ],
            ),

          // Floating top bar.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _CircleControl(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                  const Spacer(),
                  if (stops.isNotEmpty) ...[
                    _CircleControl(
                      icon: Icons.fit_screen_rounded,
                      onTap: () => _fitBounds(stops),
                    ),
                    const SizedBox(width: 8),
                    _CircleControl(
                      icon: Icons.my_location_rounded,
                      onTap: () => _centerOnDriver(locationState),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Selected stop sheet — slides in from the bottom when a marker
          // is tapped.
          AnimatedPositioned(
            duration: AppMotion.standard,
            curve: AppMotion.emphasized,
            left: 0,
            right: 0,
            bottom: _selectedStopId == null ? -260 : 0,
            child: _selectedStopId == null
                ? const SizedBox.shrink()
                : _SelectedStopSheet(
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

  Marker _buildDriverMarker(double lat, double lng) {
    return Marker(
      point: LatLng(lat, lng),
      width: 44,
      height: 44,
      child: const _PulsingDot(),
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

class _CircleControl extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleControl({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.bgSurfaceElevated,
          borderRadius: AppRadius.rFull,
          border: Border.all(color: AppColors.borderSubtle, width: 1),
          boxShadow: AppShadows.elevated,
        ),
        child: Icon(icon, size: 18, color: AppColors.fgPrimary),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse ring.
            Opacity(
              opacity: 1 - t,
              child: Container(
                width: 16 + (t * 28),
                height: 16 + (t * 28),
                decoration: const BoxDecoration(
                  color: AppColors.accentLive,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Solid core.
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.accentLive,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.bgBase, width: 2),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SelectedStopSheet extends StatelessWidget {
  final RouteStop stop;
  final VoidCallback onClose;
  final void Function(RouteStop) onNavigate;
  final void Function(RouteStop) onDetails;

  const _SelectedStopSheet({
    required this.stop,
    required this.onClose,
    required this.onNavigate,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '#${stop.sequence}',
                  style: AppTypography.statMedium.copyWith(fontSize: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stop.displayName,
                    style: AppTypography.h4,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                StatusPill(status: stop.status, dense: true),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.fgTertiary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    stop.address,
                    style: AppTypography.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Detalle',
                    icon: Icons.info_outline_rounded,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.lg,
                    fullWidth: true,
                    onPressed: () => onDetails(stop),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: 'Navegar',
                    icon: Icons.navigation_rounded,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.lg,
                    fullWidth: true,
                    onPressed: () => onNavigate(stop),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.map_outlined,
            size: 32,
            color: AppColors.fgTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            'Sin paradas para mostrar',
            style: AppTypography.body.copyWith(color: AppColors.fgSecondary),
          ),
        ],
      ),
    );
  }
}
