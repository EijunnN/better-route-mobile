import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../router/router.dart';

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
    final theme = Theme.of(context);

    return SafeArea(
      child: Scaffold(
      headers: [
        AppBar(
          title: const Text('Mapa de ruta'),
          leading: [
            IconButton.ghost(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ],
          trailing: [
            if (stops.isNotEmpty)
              IconButton.ghost(
                icon: const Icon(Icons.fit_screen),
                onPressed: () => _fitBounds(stops),
              ),
          ],
        ),
      ],
      child: stops.isEmpty
          ? _buildEmptyState()
          : Stack(
              children: [
                // Map
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter:
                        _getInitialCenter(stops, locationState),
                    initialZoom: 13,
                    onTap: (_, _) =>
                        setState(() => _selectedStopId = null),
                  ),
                  children: [
                    // OpenStreetMap tiles
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.betterroute.aea',
                    ),

                    // Route polyline connecting stops in order
                    if (stops.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: stops
                                .map((s) =>
                                    LatLng(s.latitude, s.longitude))
                                .toList(),
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.6),
                            strokeWidth: 3,
                          ),
                        ],
                      ),

                    // Stop markers
                    MarkerLayer(
                      markers: stops
                          .map((stop) => _buildStopMarker(stop))
                          .toList(),
                    ),

                    // Driver current location
                    if (locationState.currentLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              locationState.currentLocation!.latitude,
                              locationState.currentLocation!.longitude,
                            ),
                            width: 32,
                            height: 32,
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.secondary
                                        .withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.navigation,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                // Selected stop detail card
                if (_selectedStopId != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: _buildSelectedStopCard(stops),
                  ),
              ],
            ),
    ),
    );
  }

  Marker _buildStopMarker(RouteStop stop) {
    final isSelected = _selectedStopId == stop.id;
    final color = _getStatusColor(stop.status);
    final size = isSelected ? 44.0 : 36.0;

    return Marker(
      point: LatLng(stop.latitude, stop.longitude),
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedStopId = stop.id);
          _mapController.move(
            LatLng(stop.latitude, stop.longitude),
            _mapController.camera.zoom,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.9),
              width: isSelected ? 3 : 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 1)
                  ]
                : [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4)
                  ],
          ),
          child: Center(
            child: Text(
              '${stop.sequence}',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSelected ? 16 : 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedStopCard(List<RouteStop> stops) {
    final stop = stops.firstWhere(
      (s) => s.id == _selectedStopId,
      orElse: () => stops.first,
    );
    final statusColor = _getStatusColor(stop.status);
    final statusLabel = _getStatusLabel(stop.status);
    final theme = Theme.of(context);

    return Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: sequence + name + status
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${stop.sequence}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ).semiBold(),
                    if (stop.order?.trackingId != null)
                      Text(
                        stop.order!.trackingId!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
              SecondaryBadge(
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Address
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 16, color: theme.colorScheme.mutedForeground),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  stop.address,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.mutedForeground,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlineButton(
                  onPressed: () =>
                      context.push(AppRoutes.stopDetailPath(stop.id)),
                  leading: const Icon(Icons.info_outline, size: 18),
                  child: const Text('Ver detalle'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  onPressed: () {
                    ref.read(locationProvider.notifier).navigateTo(
                          stop.latitude,
                          stop.longitude,
                        );
                  },
                  leading: const Icon(Icons.navigation, size: 18),
                  child: const Text('Navegar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined,
              size: 64, color: theme.colorScheme.mutedForeground),
          const SizedBox(height: 16),
          const Text('Sin paradas para mostrar').muted(),
        ],
      ),
    );
  }

  LatLng _getInitialCenter(
      List<RouteStop> stops, LocationState locationState) {
    if (locationState.currentLocation != null) {
      return LatLng(
        locationState.currentLocation!.latitude,
        locationState.currentLocation!.longitude,
      );
    }
    if (stops.isNotEmpty) {
      return LatLng(stops.first.latitude, stops.first.longitude);
    }
    return const LatLng(-12.046374, -77.042793); // Lima default
  }

  void _fitBounds(List<RouteStop> stops) {
    if (stops.isEmpty) return;
    final points =
        stops.map((s) => LatLng(s.latitude, s.longitude)).toList();

    // Add current location to bounds
    final locationState = ref.read(locationProvider);
    if (locationState.currentLocation != null) {
      points.add(LatLng(
        locationState.currentLocation!.latitude,
        locationState.currentLocation!.longitude,
      ));
    }

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  Color _getStatusColor(StopStatus status) {
    switch (status) {
      case StopStatus.completed:
        return StatusColors.completed;
      case StopStatus.failed:
        return StatusColors.failed;
      case StopStatus.skipped:
        return StatusColors.skipped;
      case StopStatus.inProgress:
        return StatusColors.inProgress;
      case StopStatus.pending:
        return StatusColors.pending;
    }
  }

  String _getStatusLabel(StopStatus status) {
    switch (status) {
      case StopStatus.completed:
        return 'Completada';
      case StopStatus.failed:
        return 'Fallida';
      case StopStatus.skipped:
        return 'Omitida';
      case StopStatus.inProgress:
        return 'En progreso';
      case StopStatus.pending:
        return 'Pendiente';
    }
  }
}
