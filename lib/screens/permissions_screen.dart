import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/design/tokens.dart';
import '../providers/providers.dart';
import '../router/router.dart';
import '../services/location_service.dart';
import '../widgets/app/app.dart';

/// Permisos — pre-prompt screen shown after first login.
///
/// Spec: `Mobile - Specs.html` § 07 / 02 · Permisos (mirrors
/// `MobPermisos`). The whole point is to *educate before asking*:
/// drivers say no on impulse to a raw OS dialog, but accept happily
/// when they understand why we need the access. This screen is the
/// classic "pre-prompt" pattern — show context first, then chain the
/// real OS dialogs.
///
/// Hero (260h) → eyebrow + h1 + body → 3 permission rows → privacy
/// footer → primary CTA (chain prompts) + ghost CTA (manual settings).
///
/// We currently only have a runtime hook for location (geolocator).
/// Camera + notifications are pre-declared in the Android manifest, so
/// the system will surface their dialogs the first time the relevant
/// feature is used. This screen still lists them so the driver knows
/// what's coming.
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  bool _requesting = false;

  Future<void> _grantAndContinue() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      final status =
          await ref.read(locationProvider.notifier).requestPermissions();
      if (!mounted) return;
      // Even if the driver only granted foreground access, we still
      // let them in — the home screen surfaces a banner pushing them
      // toward background later. Outright denial keeps them here so
      // they can retry or open settings manually.
      if (status != LocationPermissionStatus.denied &&
          status != LocationPermissionStatus.deniedForever) {
        context.go(AppRoutes.home);
      } else {
        await ref.read(locationProvider.notifier).openAppSettings();
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  void _skipForNow() {
    // Manual config — same fallback as denial: let them through, the
    // banner on home will keep nudging them.
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final status =
        ref.watch(locationProvider.select((s) => s.permissionStatus));
    final locationGranted =
        status == LocationPermissionStatus.background ||
            status == LocationPermissionStatus.foregroundOnly;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // Hero illustration — 260h, fixed.
            const SizedBox(
              height: 260,
              child: CustomPaint(
                size: Size.infinite,
                painter: _PermissionsHeroPainter(),
              ),
            ),

            // Scrollable body — overline, hero copy, perm rows.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ANTES DE EMPEZAR',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.lime,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Necesitamos\ntres permisos.',
                      style: AppTypography.h1.copyWith(
                        fontSize: 26,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sin esto, no podemos hacer el seguimiento de tu ruta '
                      'ni que el despacho te avise de cambios.',
                      style: AppTypography.body.copyWith(
                        color: AppColors.fgSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Three permission rows. Location reflects real
                    // OS state; the others are pre-prompts.
                    _PermRow(
                      icon: Icons.location_on_outlined,
                      title: 'Tu ubicación',
                      sub: 'Para guiarte por la ruta y avisar al cliente '
                          'cuando estés cerca.',
                      granted: locationGranted,
                      required: true,
                    ),
                    const SizedBox(height: 10),
                    const _PermRow(
                      icon: Icons.camera_alt_outlined,
                      title: 'Cámara',
                      sub: 'Para tomar foto del paquete entregado como '
                          'comprobante.',
                      granted: false,
                      required: true,
                    ),
                    const SizedBox(height: 10),
                    const _PermRow(
                      icon: Icons.notifications_outlined,
                      title: 'Notificaciones',
                      sub: 'Te avisamos si despacho cambia tu ruta o te '
                          'manda un mensaje.',
                      granted: false,
                      required: false,
                    ),
                  ],
                ),
              ),
            ),

            // Bottom — privacy footer + CTAs. Pinned, outside scroll.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: AppRadius.rMd,
                      border: Border.all(
                        color: AppColors.borderSubtle,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: AppColors.fgTertiary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tu ubicación solo se comparte mientras estás en '
                            'turno. Podés cortarla en cualquier momento.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.fgTertiary,
                              fontSize: 11.5,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: locationGranted
                        ? 'Continuar'
                        : 'Dar permisos y continuar',
                    trailingIcon: Icons.arrow_forward_rounded,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.lg,
                    fullWidth: true,
                    isLoading: _requesting,
                    onPressed: _grantAndContinue,
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _skipForNow,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.fgTertiary,
                      minimumSize: const Size.fromHeight(38),
                    ),
                    child: Text(
                      'Configurar manualmente',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.fgTertiary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Single permission row — icon, title (+ optional "Requerido" badge),
// description, and a right-aligned status indicator (check or dot).
// ─────────────────────────────────────────────────────────────────────

class _PermRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final bool granted;
  final bool required;

  const _PermRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.granted,
    required this.required,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: AppRadius.rMd,
        border: Border.all(
          color: granted
              ? AppColors.lime.withValues(alpha: 0.3)
              : AppColors.borderSubtle,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon bubble.
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: granted
                  ? AppColors.limeSoft
                  : AppColors.bgSurfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 18,
              color: granted ? AppColors.lime : AppColors.fgSecondary,
            ),
          ),
          const SizedBox(width: 12),
          // Title + description.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: AppTypography.bodyMedium),
                    if (required) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'REQUERIDO',
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                            letterSpacing: 0.6,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: AppTypography.bodySmall.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Status indicator.
          granted
              ? Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppColors.lime,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: AppColors.fgInverse,
                  ),
                )
              : Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.fgTertiary,
                    shape: BoxShape.circle,
                  ),
                ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Hero illustration painter.
//
// Layers: radial lime glow → fine grid → dashed faux-route trail →
// central pin (concentric circles with lime fill and a "+" hint icon)
// → two satellite icons (mail/notif) on either side.
//
// Pure CustomPainter so it renders at any resolution without assets.
// ─────────────────────────────────────────────────────────────────────

class _PermissionsHeroPainter extends CustomPainter {
  const _PermissionsHeroPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Radial green glow centred slightly below mid-Y, to match the
    // design's "circle at 50% 60%".
    final glowCentre = Offset(w * 0.5, h * 0.6);
    final glowRadius = w * 0.6;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.limeDim.withValues(alpha: 0.4),
          AppColors.limeDim.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: glowCentre, radius: glowRadius),
      );
    canvas.drawCircle(glowCentre, glowRadius, glow);

    // 2. Grid — 28×28, very dim hairlines.
    final gridPaint = Paint()
      ..color = AppColors.borderSubtle.withValues(alpha: 0.4)
      ..strokeWidth = 0.7;
    const step = 28.0;
    for (var x = 0.0; x < w; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (var y = 0.0; y < h; y += step) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // 3. Dashed lime trail — five points across the upper half.
    const designW = 380.0;
    const designH = 260.0;
    final sx = w / designW;
    final sy = h / designH;
    final trailPts = [
      Offset(80 * sx, 200 * sy),
      Offset(130 * sx, 160 * sy),
      Offset(200 * sx, 140 * sy),
      Offset(270 * sx, 120 * sy),
      Offset(320 * sx, 90 * sy),
    ];
    _drawDashedPolyline(
      canvas,
      trailPts,
      Paint()
        ..color = AppColors.lime
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
      dash: 6,
      gap: 4,
    );

    // 4. Central pin — concentric circles.
    final pin = Offset(190 * sx, 130 * sy);

    // Outer ring (dark, subtle border).
    canvas.drawCircle(
      pin,
      48,
      Paint()..color = AppColors.bgSurface,
    );
    canvas.drawCircle(
      pin,
      48,
      Paint()
        ..color = AppColors.borderStrong
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Mid ring (lime soft halo).
    canvas.drawCircle(
      pin,
      38,
      Paint()..color = AppColors.lime.withValues(alpha: 0.18),
    );
    // Solid lime core.
    canvas.drawCircle(pin, 22, Paint()..color = AppColors.lime);
    // "+" hint on top of the pin core.
    final plus = Paint()
      ..color = AppColors.fgInverse
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(pin.dx, pin.dy - 10),
      Offset(pin.dx, pin.dy + 5),
      plus,
    );
    canvas.drawLine(
      Offset(pin.dx - 5, pin.dy),
      Offset(pin.dx + 5, pin.dy),
      plus,
    );

    // 5. Two satellite icons — one upper-left (mail in amber), one
    // lower-right (notification in info blue).
    _drawSatellite(
      canvas,
      Offset(70 * sx, 90 * sy),
      _SatelliteKind.mail,
    );
    _drawSatellite(
      canvas,
      Offset(310 * sx, 170 * sy),
      _SatelliteKind.bell,
    );
  }

  void _drawSatellite(Canvas canvas, Offset c, _SatelliteKind kind) {
    // Background circle.
    canvas.drawCircle(
      c,
      20,
      Paint()..color = AppColors.bgSurfaceElevated,
    );
    canvas.drawCircle(
      c,
      20,
      Paint()
        ..color = AppColors.borderStrong
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // Glyph.
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4
      ..color = kind == _SatelliteKind.mail
          ? AppColors.warning
          : AppColors.info;
    if (kind == _SatelliteKind.mail) {
      // Three horizontal lines suggesting a list / message.
      canvas.drawLine(
        Offset(c.dx - 5, c.dy - 6),
        Offset(c.dx + 5, c.dy - 6),
        stroke,
      );
      canvas.drawLine(
        Offset(c.dx - 5, c.dy - 3),
        Offset(c.dx + 5, c.dy - 3),
        stroke,
      );
      canvas.drawLine(
        Offset(c.dx - 5, c.dy),
        Offset(c.dx + 5, c.dy),
        stroke,
      );
      canvas.drawLine(
        Offset(c.dx - 5, c.dy + 3),
        Offset(c.dx + 1, c.dy + 3),
        stroke,
      );
    } else {
      // Bell glyph — small circle + cap.
      canvas.drawCircle(c, 6, stroke);
      canvas.drawRect(
        Rect.fromCenter(center: Offset(c.dx, c.dy - 7.5), width: 6, height: 3),
        Paint()..color = AppColors.info,
      );
    }
  }

  void _drawDashedPolyline(
    Canvas canvas,
    List<Offset> pts,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    if (pts.length < 2) return;
    // Compute total length and walk a fraction.
    var carry = 0.0;
    var drawing = true;
    for (var i = 0; i < pts.length - 1; i++) {
      var start = pts[i];
      final end = pts[i + 1];
      final segVec = end - start;
      final segLen = segVec.distance;
      if (segLen == 0) continue;
      final dir = segVec / segLen;
      var travelled = 0.0;
      while (travelled < segLen) {
        final piece = (drawing ? dash : gap) - carry;
        final available = segLen - travelled;
        if (piece >= available) {
          final endPoint = start + dir * available;
          if (drawing) {
            canvas.drawLine(start, endPoint, paint);
          }
          carry = piece - available;
          travelled = segLen;
        } else {
          final endPoint = start + dir * piece;
          if (drawing) {
            canvas.drawLine(start, endPoint, paint);
          }
          start = endPoint;
          travelled += piece;
          drawing = !drawing;
          carry = 0;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _SatelliteKind { mail, bell }
