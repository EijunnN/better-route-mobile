import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/design/tokens.dart';
import '../models/route_stop.dart';
import '../providers/providers.dart';
import '../router/router.dart';
import '../services/location_service.dart';
import '../widgets/app/app.dart';
import '../widgets/shared/shared.dart';
import 'home/widgets/widgets.dart';

/// Driver Cockpit home — agenda-first.
///
/// Top bar (driver identity + logout) → KPI strip → segmented filter
/// → dense agenda list of stops → primary CTA "Abrir mapa". The screen
/// owns providers and orchestration; visual subwidgets live in
/// `home/widgets/`.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  HomeStopFilter _filter = HomeStopFilter.pending;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(routeProvider.notifier).loadRoute();
      ref.read(workflowProvider.notifier).loadStates();
      ref.read(fieldDefinitionProvider.notifier).loadDefinitions();
      ref.read(locationProvider.notifier).startTracking();
      ref.read(trackingProvider.notifier).startTracking();
    });
  }

  Future<void> _onRefresh() async {
    await ref.read(routeProvider.notifier).refresh();
  }

  Future<void> _resolvePermission(LocationPermissionStatus status) async {
    final notifier = ref.read(locationProvider.notifier);
    switch (status) {
      case LocationPermissionStatus.serviceDisabled:
        await notifier.openLocationSettings();
        break;
      case LocationPermissionStatus.deniedForever:
        await notifier.openAppSettings();
        break;
      case LocationPermissionStatus.denied:
      case LocationPermissionStatus.foregroundOnly:
        await notifier.requestPermissions();
        // If we just got a fresh grant, kick tracking again so the
        // foreground service binds with the upgraded permission.
        if (!ref.read(locationProvider).isTracking) {
          await notifier.startTracking();
          await ref.read(trackingProvider.notifier).startTracking();
        }
        break;
      case LocationPermissionStatus.background:
        break;
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.bgOverlay,
      builder: (context) => const HomeLogoutDialog(),
    );
    if (confirmed == true) {
      ref.read(locationProvider.notifier).stopTracking();
      ref.read(trackingProvider.notifier).stopTracking();
      ref.read(routeProvider.notifier).clear();
      ref.read(workflowProvider.notifier).clear();
      ref.read(fieldDefinitionProvider.notifier).clear();
      await ref.read(authProvider.notifier).logout();
    }
  }

  List<RouteStop> _filtered(List<RouteStop> all) {
    switch (_filter) {
      case HomeStopFilter.all:
        return all;
      case HomeStopFilter.pending:
        return all.where((s) => !s.status.isDone).toList();
      case HomeStopFilter.done:
        return all.where((s) => s.status.isDone).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeState = ref.watch(routeProvider);
    final permissionStatus =
        ref.watch(locationProvider.select((s) => s.permissionStatus));
    final stops = _filtered(routeState.stops);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: routeState.isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.fgPrimary,
                  strokeWidth: 2,
                ),
              )
            : RefreshIndicator(
                onRefresh: _onRefresh,
                color: AppColors.fgPrimary,
                backgroundColor: AppColors.bgSurfaceElevated,
                displacement: 80,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: HomeTopBar(
                        driverName: routeState.driver?.name ?? 'Conductor',
                        onLogout: _logout,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: BackgroundPermissionBanner(
                        status: permissionStatus,
                        onAction: () => _resolvePermission(permissionStatus),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: HomeKpiStrip(
                        allStops: routeState.stops,
                        metrics: routeState.metrics,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: HomeFilters(
                        current: _filter,
                        counts: {
                          HomeStopFilter.all: routeState.stops.length,
                          HomeStopFilter.pending: routeState.stops
                              .where((s) => !s.status.isDone)
                              .length,
                          HomeStopFilter.done: routeState.stops
                              .where((s) => s.status.isDone)
                              .length,
                        },
                        onChange: (f) => setState(() => _filter = f),
                      ),
                    ),
                    if (stops.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: HomeEmptyState(
                          filter: _filter,
                          onRefresh: _onRefresh,
                        ),
                      )
                    else
                      SliverList.separated(
                        itemCount: stops.length,
                        separatorBuilder: (_, _) => const StopRowDivider(),
                        itemBuilder: (context, index) {
                          final stop = stops[index];
                          return StopRow(
                            stop: stop,
                            onTap: () => context
                                .push(AppRoutes.stopDetailPath(stop.id)),
                          );
                        },
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 96)),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: routeState.stops.isEmpty
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: AppButton(
                  label: 'Abrir mapa de ruta',
                  icon: Icons.map_outlined,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.lg,
                  fullWidth: true,
                  onPressed: () => context.push(AppRoutes.routeMap),
                ),
              ),
            ),
    );
  }
}
