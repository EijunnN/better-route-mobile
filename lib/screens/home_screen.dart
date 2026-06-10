import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/design/tokens.dart';
import '../models/route_stop.dart';
import '../providers/providers.dart';
import '../router/router.dart';
import '../services/location_service.dart';
import '../services/offline_outbox.dart';
import '../widgets/app/app.dart';
import '../widgets/shared/shared.dart';
import 'home/widgets/widgets.dart';

/// Driver Cockpit home — map peek + agenda + bottom nav.
///
/// Spec: `Mobile - Specs.html` § 07 / 03 · Home (D2). The screen lays
/// out as a single scrollable column under a floating glass top bar:
///
///   [GlassTopBar (over the map)]
///   ┌── 280h MapPeek ─────────────┐
///   │  (CustomPainter route)      │
///   │            ↓ fade to bg     │
///   └─────────────────────────────┘
///   [-16px overlap]
///   ┌── KPI card ─────────────────┐
///   [HomeFilters segmented]
///   [Stop rows ...]
///   ───────────────────────────────
///   [HomeBottomNav 3 tabs]
///
/// The bottom nav is the canonical entry point for /home/map and
/// /chat — the previous FAB + "Abrir mapa" CTA are gone, replaced by
/// the bottom tabs which feel more native to a driver shell.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  HomeStopFilter _filter = HomeStopFilter.pending;
  Timer? _routeRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Drain any closes queued from a prior offline session, and keep retrying
    // on a timer while the driver is on shift.
    OfflineOutbox().startAutoFlush();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(routeProvider.notifier).loadRoute();
      ref.read(workflowProvider.notifier).loadStates();
      ref.read(fieldDefinitionProvider.notifier).loadDefinitions();
      ref.read(locationProvider.notifier).startTracking();
      ref.read(trackingProvider.notifier).startTracking();
    });
    // El ETA en vivo se recalcula en el backend con cada ping GPS; este
    // poll trae los valores frescos sin que el driver tenga que hacer
    // pull-to-refresh.
    _routeRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => ref.read(routeProvider.notifier).refresh(),
    );
  }

  @override
  void dispose() {
    _routeRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    OfflineOutbox().stopAutoFlush();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(locationProvider.notifier).checkPermission();
      // Coming back to the foreground is a good moment to sync queued closes.
      OfflineOutbox().flush();
    }
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
      case LocationPermissionStatus.foregroundOnly:
        if (Platform.isAndroid) {
          await notifier.openAppSettings();
        } else {
          await notifier.requestPermissions();
          if (!ref.read(locationProvider).isTracking) {
            await notifier.startTracking();
            await ref.read(trackingProvider.notifier).startTracking();
          }
        }
        break;
      case LocationPermissionStatus.denied:
        await notifier.requestPermissions();
        if (!ref.read(locationProvider).isTracking) {
          await notifier.startTracking();
          await ref.read(trackingProvider.notifier).startTracking();
        }
        break;
      case LocationPermissionStatus.background:
        break;
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

  void _onTabChange(HomeNavTab tab) {
    switch (tab) {
      case HomeNavTab.agenda:
        // Already here — no-op.
        break;
      case HomeNavTab.map:
        context.push(AppRoutes.routeMap);
        break;
      case HomeNavTab.chat:
        context.push(AppRoutes.chat);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeState = ref.watch(routeProvider);
    final permissionStatus = ref.watch(
      locationProvider.select((s) => s.permissionStatus),
    );

    // Sort stops by sequence for the peek so the polyline order is
    // deterministic regardless of how the API returned them.
    final allStops = [...routeState.stops]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final stops = _filtered(allStops);
    final completed = allStops.where((s) => s.status.isCompleted).length;

    // "ETA fin": el mayor ETA en vivo de las paradas pendientes manda;
    // fallback al fin de ventana más tardío cuando no hay recálculo.
    String? etaEnd;
    final lastLiveEta = allStops
        .where((s) => s.status.isPending || s.status.isInProgress)
        .map((s) => s.liveEtaAt)
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (acc, dt) => acc == null || dt.isAfter(acc) ? dt : acc,
        );
    final lastEnd =
        lastLiveEta ??
        allStops
            .map((s) => s.timeWindow?.end)
            .whereType<DateTime>()
            .fold<DateTime?>(
              null,
              (acc, dt) => acc == null || dt.isAfter(acc) ? dt : acc,
            );
    if (lastEnd != null) {
      final l = lastEnd.toLocal();
      etaEnd =
          '${l.hour.toString().padLeft(2, '0')}:'
          '${l.minute.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: routeState.isLoading
          ? const _HomeLoading()
          : Stack(
              children: [
                // Scrollable column.
                Positioned.fill(
                  child: RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: AppColors.lime,
                    backgroundColor: AppColors.bgSurfaceElevated,
                    displacement: 320,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // Map peek with a transparent area on top so
                        // the GlassTopBar shows through.
                        SliverToBoxAdapter(
                          child: HomeMapPeek(
                            stops: allStops,
                            geometry: routeState.data?.route?.geometry,
                            onTap: () => context.push(AppRoutes.routeMap),
                          ),
                        ),

                        // KPI card right below the map peek. We tried
                        // a -16px Transform.translate to "lift" the
                        // card onto the map (per the design's
                        // overlap), but that collided with the
                        // floating "Ver mapa completo" pill which
                        // also lives at the map's bottom edge. The
                        // map peek's bottom-fade gradient already
                        // gives the "card emerging from map" feel
                        // without the overlap, so we just sit the
                        // card naturally below and add a sliver of
                        // breathing room.
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                        SliverToBoxAdapter(
                          child: HomeKpiCard(
                            completed: completed,
                            total: allStops.length,
                            etaEnd: etaEnd,
                          ),
                        ),

                        // Permission banner (if any).
                        SliverToBoxAdapter(
                          child: BackgroundPermissionBanner(
                            status: permissionStatus,
                            onAction: () =>
                                _resolvePermission(permissionStatus),
                          ),
                        ),

                        // Offline outbox status — closes captured in a
                        // no-signal zone, syncing in the background.
                        const SliverToBoxAdapter(child: _OutboxBanner()),

                        // Filter chips.
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: HomeFilters(
                              current: _filter,
                              counts: {
                                HomeStopFilter.all: allStops.length,
                                HomeStopFilter.pending: allStops
                                    .where((s) => !s.status.isDone)
                                    .length,
                                HomeStopFilter.done: allStops
                                    .where((s) => s.status.isDone)
                                    .length,
                              },
                              onChange: (f) => setState(() => _filter = f),
                            ),
                          ),
                        ),

                        // Stop list (or empty state). The empty state
                        // uses SliverFillRemaining so it can take all
                        // the space below the KPI without a fixed
                        // height (the hero pulse + text + actions card
                        // + CTA need ~480px and overflow if we cap it).
                        if (stops.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: HomeEmptyState(
                              filter: _filter,
                              onRefresh: _onRefresh,
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            sliver: SliverList.separated(
                              itemCount: stops.length,
                              separatorBuilder: (_, _) =>
                                  const StopRowDivider(),
                              itemBuilder: (context, index) {
                                final stop = stops[index];
                                return StopRow(
                                  stop: stop,
                                  onTap: () => context.push(
                                    AppRoutes.stopDetailPath(stop.id),
                                  ),
                                );
                              },
                            ),
                          ),

                        // Tail spacer so the last row sits above the
                        // bottom nav comfortably.
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    ),
                  ),
                ),

                // GlassTopBar floats above the map peek (SafeArea
                // applied here so the pills sit below the status bar).
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: GlassTopBar(
                      // Prefer the route's driver name (it has the
                      // canonical casing from the route response),
                      // but fall back to the auth user's name so the
                      // top bar shows "Esperanza" the moment login
                      // finishes — not the generic "Conductor"
                      // placeholder while /my-route is still in flight.
                      driverName:
                          routeState.driver?.name ??
                          ref.watch(authProvider).user?.name ??
                          'Conductor',
                      onChatTap: () => context.push(AppRoutes.chat),
                      // Tap → End of day. The summary screen has its
                      // own "Cerrar turno" CTA that runs the actual
                      // logout flow, so we get a "see your day before
                      // you sign off" path for free.
                      onAvatarTap: () {
                        HapticFeedback.lightImpact();
                        context.push(AppRoutes.endOfDay);
                      },
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: HomeBottomNav(
        current: HomeNavTab.agenda,
        onChange: _onTabChange,
      ),
    );
  }
}

/// Thin banner that surfaces stop closes captured offline and waiting to
/// sync. Watches the outbox's pending count; collapses to nothing at zero.
class _OutboxBanner extends StatelessWidget {
  const _OutboxBanner();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: OfflineOutbox().pendingCount,
      builder: (context, count, _) {
        if (count <= 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: AppRadius.rMd,
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sync_rounded,
                  size: 16,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    count == 1
                        ? '1 entrega guardada sin señal — se enviará al reconectar'
                        : '$count entregas guardadas sin señal — se enviarán al reconectar',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.fgPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(color: AppColors.lime, strokeWidth: 2),
      ),
    );
  }
}
