import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
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

    // Load route data and start location tracking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(routeProvider.notifier).loadRoute();
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Cerrar sesion'),
        content: const Text('Estas seguro que deseas cerrar sesion?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Cerrar sesion'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(locationProvider.notifier).stopTracking();
      ref.read(trackingProvider.notifier).stopTracking();
      ref.read(routeProvider.notifier).clear();
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeState = ref.watch(routeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with driver info and logout
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
                color: theme.colorScheme.surface,
                border: Border(
                  bottom: BorderSide(color: AppColors.border),
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
                    routeState.stops
                        .where((s) => !s.status.isDone)
                        .length,
                  ),
                  _buildTab(
                    'Completadas',
                    routeState.stops
                        .where((s) => s.status.isDone)
                        .length,
                  ),
                ],
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Content
            Expanded(
              child: routeState.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
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
      color: AppColors.primary,
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
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.route_outlined,
                size: 36,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sin paradas',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'No tienes paradas asignadas\npara hoy',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _onRefresh,
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Actualizar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
