import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/design/tokens.dart';
import '../models/route_data.dart';
import '../models/route_stop.dart';
import '../providers/providers.dart';
import '../router/router.dart';
import '../widgets/app/app.dart';

/// Driver Cockpit home — agenda-first.
///
/// Layout: minimal top bar (driver identity + logout) → KPI strip
/// (4 stat blocks) → segmented filter (All / Pending / Done) → dense
/// agenda list of stops. Map FAB replaced with a primary CTA at the
/// bottom because there's only ONE next step from this screen.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

enum _StopFilter { all, pending, done }

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _StopFilter _filter = _StopFilter.pending;

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

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.bgOverlay,
      builder: (context) => const _LogoutDialog(),
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
      case _StopFilter.all:
        return all;
      case _StopFilter.pending:
        return all.where((s) => !s.status.isDone).toList();
      case _StopFilter.done:
        return all.where((s) => s.status.isDone).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeState = ref.watch(routeProvider);
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
                      child: _TopBar(
                        driverName: routeState.driver?.name ?? 'Conductor',
                        onLogout: _logout,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _KpiStrip(
                        allStops: routeState.stops,
                        metrics: routeState.metrics,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _Filters(
                        current: _filter,
                        counts: {
                          _StopFilter.all: routeState.stops.length,
                          _StopFilter.pending: routeState.stops
                              .where((s) => !s.status.isDone)
                              .length,
                          _StopFilter.done: routeState.stops
                              .where((s) => s.status.isDone)
                              .length,
                        },
                        onChange: (f) => setState(() => _filter = f),
                      ),
                    ),
                    if (stops.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(filter: _filter, onRefresh: _onRefresh),
                      )
                    else
                      SliverList.separated(
                        itemCount: stops.length,
                        separatorBuilder: (_, _) => const StopRowDivider(),
                        itemBuilder: (context, index) {
                          final stop = stops[index];
                          return StopRow(
                            stop: stop,
                            onTap: () =>
                                context.push(AppRoutes.stopDetailPath(stop.id)),
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

class _TopBar extends StatelessWidget {
  final String driverName;
  final VoidCallback onLogout;

  const _TopBar({required this.driverName, required this.onLogout});

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceElevated,
              borderRadius: AppRadius.rFull,
              border: Border.all(color: AppColors.borderSubtle, width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(driverName),
              style: AppTypography.label.copyWith(color: AppColors.fgPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hoy', style: AppTypography.overline),
                const SizedBox(height: 2),
                Text(
                  driverName,
                  style: AppTypography.h4,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onLogout();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: AppRadius.rFull,
                border: Border.all(color: AppColors.borderSubtle, width: 1),
              ),
              child: const Icon(
                Icons.logout_rounded,
                size: 16,
                color: AppColors.fgSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  final List<RouteStop> allStops;
  final RouteMetrics? metrics;

  const _KpiStrip({required this.allStops, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final pending = allStops.where((s) => !s.status.isDone).length;
    final done = allStops.where((s) => s.status.isDone).length;
    final distanceKm = metrics != null
        ? (metrics!.totalDistance / 1000).toStringAsFixed(1)
        : null;
    final durationMin = metrics != null
        ? (metrics!.totalDuration / 60).round().toString()
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.8,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: [
          KpiBlock(
            value: pending.toString(),
            label: 'Pendientes',
            icon: Icons.radio_button_unchecked_rounded,
          ),
          KpiBlock(
            value: done.toString(),
            label: 'Completadas',
            icon: Icons.check_circle_outline_rounded,
            accent: done > 0 ? AppColors.accentLive : null,
          ),
          KpiBlock(
            value: distanceKm ?? '—',
            unit: 'km',
            label: 'Distancia',
            icon: Icons.straighten_rounded,
          ),
          KpiBlock(
            value: durationMin ?? '—',
            unit: 'min',
            label: 'Duración est.',
            icon: Icons.schedule_rounded,
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final _StopFilter current;
  final Map<_StopFilter, int> counts;
  final ValueChanged<_StopFilter> onChange;

  const _Filters({
    required this.current,
    required this.counts,
    required this.onChange,
  });

  static const _labels = {
    _StopFilter.all: 'Todas',
    _StopFilter.pending: 'Pendientes',
    _StopFilter.done: 'Hechas',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: _StopFilter.values.map((f) {
          final selected = f == current;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChange(f);
              },
              child: AnimatedContainer(
                duration: AppMotion.fast,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.fgPrimary
                      : AppColors.bgSurface,
                  borderRadius: AppRadius.rFull,
                  border: Border.all(
                    color: selected
                        ? AppColors.fgPrimary
                        : AppColors.borderSubtle,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _labels[f]!,
                      style: AppTypography.label.copyWith(
                        color: selected
                            ? AppColors.fgInverse
                            : AppColors.fgPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      counts[f].toString(),
                      style: AppTypography.monoSmall.copyWith(
                        color: selected
                            ? AppColors.fgInverse.withValues(alpha: 0.6)
                            : AppColors.fgTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final _StopFilter filter;
  final Future<void> Function() onRefresh;

  const _EmptyState({required this.filter, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final messages = {
      _StopFilter.all: ('Sin paradas', 'No tenés paradas asignadas para hoy.'),
      _StopFilter.pending: ('Todo al día', 'Completaste todas las paradas pendientes.'),
      _StopFilter.done: ('Sin completadas', 'Todavía no marcaste paradas como completadas.'),
    };
    final msg = messages[filter]!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filter == _StopFilter.pending
                  ? Icons.celebration_outlined
                  : Icons.inventory_2_outlined,
              size: 32,
              color: AppColors.fgTertiary,
            ),
            const SizedBox(height: 16),
            Text(msg.$1, style: AppTypography.h3),
            const SizedBox(height: 6),
            Text(
              msg.$2,
              style: AppTypography.body.copyWith(color: AppColors.fgSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Actualizar',
              icon: Icons.refresh_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: onRefresh,
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgSurfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.rXl),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿Cerrar sesión?', style: AppTypography.h3),
            const SizedBox(height: 8),
            Text(
              'Vas a dejar de recibir actualizaciones de la ruta y se va a detener el envío de ubicación.',
              style: AppTypography.body.copyWith(color: AppColors.fgSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancelar',
                    variant: AppButtonVariant.secondary,
                    fullWidth: true,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Cerrar sesión',
                    variant: AppButtonVariant.destructive,
                    fullWidth: true,
                    onPressed: () => Navigator.pop(context, true),
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
