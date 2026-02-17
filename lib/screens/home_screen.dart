import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter/material.dart' show TabBar, TabBarView, Tab, TabController, FloatingActionButton, RefreshIndicator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../router/router.dart';
import '../widgets/stop_card.dart';
import '../widgets/metrics_header.dart';
import '../widgets/driver_header.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load route data, workflow states, and start location tracking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(routeProvider.notifier).loadRoute();
      ref.read(workflowProvider.notifier).loadStates();
      ref.read(locationProvider.notifier).startTracking();
      // Start sending location to server
      ref.read(trackingProvider.notifier).startTracking();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await ref.read(routeProvider.notifier).refresh();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesion'),
        content: const Text('Estas seguro que deseas cerrar sesion?'),
        actions: [
          OutlineButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          DestructiveButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesion'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(locationProvider.notifier).stopTracking();
      ref.read(trackingProvider.notifier).stopTracking();
      ref.read(routeProvider.notifier).clear();
      ref.read(workflowProvider.notifier).clear();
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeState = ref.watch(routeProvider);
    final theme = Theme.of(context);

    return ColoredBox(
      color: theme.colorScheme.background,
      child: SafeArea(
      child: Scaffold(
      floatingHeader: false,
      headers: [
        // Driver info header
        DriverHeader(
          driver: routeState.driver,
          vehicle: routeState.vehicle,
          onLogout: _logout,
        ),
        // Metrics summary
        if (routeState.metrics != null)
          MetricsHeader(metrics: routeState.metrics!),
        // Tab bar
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.card,
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.border),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            tabs: [
              _buildTab(
                'Todas',
                routeState.stops.length,
              ),
              _buildTab(
                'Pendientes',
                routeState.stops.where((s) => !s.status.isDone).length,
              ),
              _buildTab(
                'Completadas',
                routeState.stops.where((s) => s.status.isDone).length,
              ),
            ],
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.mutedForeground,
            indicatorColor: theme.colorScheme.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
      child: Stack(
        children: [
          // Content
          routeState.isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStopsList(
                      routeState.stops,
                      routeState.isRefreshing,
                    ),
                    _buildStopsList(
                      routeState.stops
                          .where((s) => !s.status.isDone)
                          .toList(),
                      routeState.isRefreshing,
                    ),
                    _buildStopsList(
                      routeState.stops
                          .where((s) => s.status.isDone)
                          .toList(),
                      routeState.isRefreshing,
                    ),
                  ],
                ),

          // FAB for map
          if (routeState.stops.isNotEmpty)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: () => context.push(AppRoutes.routeMap),
                tooltip: 'Ver mapa de ruta',
                child: const Icon(Icons.map_outlined),
              ),
            ),
        ],
      ),
    ),
    ),
    );
  }

  Widget _buildTab(String label, int count) {
    final theme = Theme.of(context);
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.muted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopsList(List<RouteStop> stops, bool isRefreshing) {
    if (stops.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: Theme.of(context).colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: stops.length,
        itemBuilder: (context, index) {
          final stop = stops[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: StopCard(
              stop: stop,
              onTap: () => context.push(AppRoutes.stopDetailPath(stop.id)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.muted,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.route_outlined,
                size: 36,
                color: theme.colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 20),
            const Text('Sin paradas').semiBold(),
            const SizedBox(height: 8),
            const Text(
              'No tienes paradas asignadas\npara hoy',
              textAlign: TextAlign.center,
            ).muted(),
            const SizedBox(height: 24),
            OutlineButton(
              onPressed: _onRefresh,
              leading: const Icon(Icons.refresh, size: 20),
              child: const Text('Actualizar'),
            ),
          ],
        ),
      ),
    );
  }
}
