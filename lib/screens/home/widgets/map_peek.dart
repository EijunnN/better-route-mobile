import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import '../../../core/design/tokens.dart';
import '../../../core/polyline.dart';
import '../../../models/route_stop.dart';

/// 280h stylised "map peek" for the home screen.
///
/// Spec: `Mobile - Specs.html` § 07 / 03 · Home. We deliberately keep
/// this a [CustomPainter] rather than embedding a live `flutter_map`
/// for three reasons: (1) zero network cost at the very top of the
/// most-frequented screen, (2) consistent visual language with the
/// splash / login key art, and (3) the peek is decorative — when the
/// driver wants the real map they tap "Ver mapa completo" and we route
/// to [RouteMapScreen] which IS a live map.
///
/// Stop positions come from the actual route — we project each stop's
/// lat/lng into the widget bounds using a simple equirectangular fit
/// so the relative geometry feels right (eastern stops on the right,
/// northern stops at the top). The pen-stroke order follows
/// [RouteStop.sequence].
class HomeMapPeek extends StatelessWidget {
  final List<RouteStop> stops;

  /// Polyline codificado de la ruta por calles (RouteInfo.geometry).
  /// Con geometría el trazo sigue las calles reales; sin ella se unen
  /// las paradas con rectas como antes.
  final String? geometry;
  final VoidCallback onTap;

  const HomeMapPeek({
    super.key,
    required this.stops,
    this.geometry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final path = (geometry == null || geometry!.isEmpty)
        ? const <LatLng>[]
        : decodePolyline(geometry!);

    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          // The map itself — tap goes to full /home/map.
          Positioned.fill(
            child: GestureDetector(
              onTap: onTap,
              child: CustomPaint(
                painter: _MapPeekPainter(stops: stops, path: path),
              ),
            ),
          ),

          // Bottom-fade so the peek bleeds into the KPI card below
          // without a hard seam.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 60,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.bgBase.withValues(alpha: 0.0),
                      AppColors.bgBase,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Floating "Ver mapa completo" pill.
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(child: _VerMapaPill(onTap: onTap)),
          ),
        ],
      ),
    );
  }
}

class _VerMapaPill extends StatelessWidget {
  final VoidCallback onTap;
  const _VerMapaPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xD914161A),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.map_outlined,
                    size: 14,
                    color: AppColors.fgPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Ver mapa completo',
                    style: AppTypography.label.copyWith(
                      color: AppColors.fgPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapPeekPainter extends CustomPainter {
  final List<RouteStop> stops;

  /// Ruta por calles ya decodificada. Vacía = unir paradas con rectas.
  final List<LatLng> path;

  const _MapPeekPainter({required this.stops, required this.path});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Solid base + subtle radial lime glow.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.bgBase,
    );
    final glowCentre = Offset(size.width * 0.55, size.height * 0.5);
    final glowRadius = size.width * 0.55;
    canvas.drawCircle(
      glowCentre,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.lime.withValues(alpha: 0.15),
            AppColors.lime.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: glowCentre, radius: glowRadius),
        ),
    );

    // 2. Grid — same vocab as splash / login.
    final grid = Paint()
      ..color = AppColors.borderSubtle.withValues(alpha: 0.5)
      ..strokeWidth = 0.7;
    const step = 36.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (stops.isEmpty) return;

    // 3. Project stops AND route path into the canvas with shared
    //    bounds (equirectangular, 12% padding) so the stroke and the
    //    dots stay alineados entre sí.
    final allLats = [
      for (final s in stops) s.latitude,
      for (final p in path) p.latitude,
    ];
    final allLngs = [
      for (final s in stops) s.longitude,
      for (final p in path) p.longitude,
    ];
    final projected = _project(
      [for (final s in stops) (s.latitude, s.longitude)],
      allLats,
      allLngs,
      size,
      pad: 0.12,
    );
    if (projected.length < 2 && path.length < 2) {
      // Single stop — just draw a marker centred.
      _drawCurrentMarker(canvas, Offset(size.width / 2, size.height / 2));
      return;
    }

    // 4. Polyline halo + line. La ruta REAL por calles cuando el plan
    //    trae geometría; rectas entre paradas como fallback.
    final strokePoints = path.length >= 2
        ? _project(
            [for (final p in path) (p.latitude, p.longitude)],
            allLats,
            allLngs,
            size,
            pad: 0.12,
          )
        : projected;
    final stroke = Path()
      ..moveTo(strokePoints.first.dx, strokePoints.first.dy);
    for (final p in strokePoints.skip(1)) {
      stroke.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      stroke,
      Paint()
        ..color = AppColors.lime.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      stroke,
      Paint()
        ..color = AppColors.lime
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 5. Stop dots — small white circles for done/pending, larger lime
    //    for the start, big white-with-dark-border for the current
    //    (in_progress) or first pending.
    final currentIndex = _resolveCurrentIndex(stops);
    for (var i = 0; i < projected.length; i++) {
      final p = projected[i];
      final stop = stops[i];
      if (i == currentIndex) {
        _drawCurrentMarker(canvas, p);
      } else if (stop.status.isCompleted) {
        canvas.drawCircle(
          p,
          5,
          Paint()..color = AppColors.lime,
        );
      } else if (stop.status.isFailed) {
        canvas.drawCircle(
          p,
          5,
          Paint()..color = AppColors.danger,
        );
      } else {
        canvas.drawCircle(
          p,
          5,
          Paint()..color = AppColors.fgPrimary,
        );
      }
    }
  }

  void _drawCurrentMarker(Canvas canvas, Offset p) {
    // Big white circle + dark border (matches the design's "current
    // stop" marker).
    canvas.drawCircle(p, 9, Paint()..color = AppColors.fgPrimary);
    canvas.drawCircle(
      p,
      9,
      Paint()
        ..color = AppColors.bgBase
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  /// First in_progress stop wins. If none, the first pending. If still
  /// none, the very first.
  int _resolveCurrentIndex(List<RouteStop> stops) {
    final inProg = stops.indexWhere((s) => s.status.isInProgress);
    if (inProg >= 0) return inProg;
    final pending = stops.indexWhere((s) => s.status.isPending);
    if (pending >= 0) return pending;
    return 0;
  }

  /// Equirectangular projection: scale lat/lng to canvas with padding.
  /// `boundsLats`/`boundsLngs` define el encuadre compartido (paradas +
  /// geometría) para que trazo y puntos queden alineados entre sí.
  List<Offset> _project(
    List<(double, double)> points,
    List<double> boundsLats,
    List<double> boundsLngs,
    Size size, {
    double pad = 0.1,
  }) {
    if (points.isEmpty || boundsLats.isEmpty) return const [];
    final minLat = boundsLats.reduce((a, b) => a < b ? a : b);
    final maxLat = boundsLats.reduce((a, b) => a > b ? a : b);
    final minLng = boundsLngs.reduce((a, b) => a < b ? a : b);
    final maxLng = boundsLngs.reduce((a, b) => a > b ? a : b);
    final latRange = (maxLat - minLat).abs();
    final lngRange = (maxLng - minLng).abs();
    final padX = size.width * pad;
    final padY = size.height * pad;
    final usableW = size.width - 2 * padX;
    final usableH = size.height - 2 * padY;

    return [
      for (final (lat, lng) in points)
        Offset(
          lngRange == 0
              ? size.width / 2
              : padX + ((lng - minLng) / lngRange) * usableW,
          latRange == 0
              ? size.height / 2
              : padY + ((maxLat - lat) / latRange) * usableH,
        ),
    ];
  }

  @override
  bool shouldRepaint(covariant _MapPeekPainter old) =>
      !identical(old.stops, stops) || !identical(old.path, path);
}
