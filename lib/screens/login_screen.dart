import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design/tokens.dart';
import '../providers/auth_provider.dart';
import '../widgets/app/app.dart';

/// Login — full-bleed key art.
///
/// Spec: `Mobile - Specs.html` § 07 / 01 · Login (mirrors `D3Login`
/// from the design's `d3.jsx`). The hero is a stylised sample route
/// over a dark-navy + grid backdrop with a radial lime glow, fading to
/// the body with a vertical vignette so the content is legible without
/// hiding the brand.
///
/// Layout (top → bottom inside SafeArea):
///   • Logo 32px @ top-left
///   • Spacer that pushes everything else to the bottom
///   • Eyebrow "DRIVER COCKPIT" (overline, letterSpacing ~4)
///   • Display 38, three lines, "Sin vueltas." in lime
///   • Body subtitle in fgSecondary, max 280
///   • Two inputs (correo + contraseña) with leading icons
///   • Primary CTA "Comenzar turno" with trailing play
///   • Footer: "¿Problemas? Contactá a tu coordinador."
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;

  String? _emailError;
  String? _passwordError;

  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      final email = _emailController.text.trim();
      _emailError = email.isEmpty
          ? 'Ingresá tu correo'
          : !email.contains('@')
              ? 'Ingresá un correo válido'
              : null;
      _passwordError = _passwordController.text.isEmpty
          ? 'Ingresá tu contraseña'
          : null;
      if (_emailError != null || _passwordError != null) valid = false;
    });
    return valid;
  }

  Future<void> _login() async {
    if (!_validate()) return;
    await ref.read(authProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          // Key art — grid + glow + sample route + vignette. Painted
          // once on a Sized.expand so it always fills the viewport.
          const Positioned.fill(
            child: CustomPaint(painter: _LoginKeyArtPainter()),
          ),

          SafeArea(
            child: AnimatedBuilder(
              animation: _intro,
              builder: (context, child) {
                final t = Curves.easeOutCubic.transform(_intro.value);
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 16),
                    child: child,
                  ),
                );
              },
              // The viewport-fill + scroll dance: we want the bottom
              // content (hero text + form) anchored to the bottom on
              // tall screens, but the whole thing still has to scroll
              // when the keyboard opens. Spacer() needs bounded
              // constraints, which a plain SingleChildScrollView
              // doesn't give — so we wrap in LayoutBuilder + Intrinsic
              // height. The Column ends up with minHeight = viewport
              // and maxHeight = intrinsic, and Spacer flexes inside.
              child: LayoutBuilder(
                builder: (context, viewport) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: viewport.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      // Logo top-left.
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CustomPaint(painter: _LogoMarkPainter()),
                      ),

                      const Spacer(),

                      // Eyebrow.
                      Text(
                        'DRIVER COCKPIT',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 4,
                          color: AppColors.fgTertiary,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Hero — three lines, last word in lime.
                      RichText(
                        text: TextSpan(
                          style: AppTypography.h1.copyWith(
                            fontSize: 38,
                            height: 1.05,
                            letterSpacing: -0.8,
                            fontWeight: FontWeight.w700,
                          ),
                          children: const [
                            TextSpan(text: 'Tu ruta.\nTu día.\n'),
                            TextSpan(
                              text: 'Sin vueltas.',
                              style: TextStyle(color: AppColors.lime),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Subtitle, capped at 280 to match the design.
                      SizedBox(
                        width: 280,
                        child: Text(
                          'Iniciá sesión y empezamos. Tu ruta de hoy ya está cargada.',
                          style: AppTypography.body.copyWith(
                            color: AppColors.fgSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Backend-side auth error surfaced separately from
                      // inline field validation, mirroring the previous
                      // login's resilience.
                      if (authState.error != null) ...[
                        _ErrorBanner(message: authState.error!),
                        const SizedBox(height: 16),
                      ],

                      AppTextField(
                        controller: _emailController,
                        label: 'Correo',
                        placeholder: 'tu@empresa.com',
                        leadingIcon: Icons.alternate_email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        errorText: _emailError,
                        onChanged: (_) {
                          if (_emailError != null) {
                            setState(() => _emailError = null);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _passwordController,
                        label: 'Contraseña',
                        placeholder: '••••••••',
                        leadingIcon: Icons.lock_outline_rounded,
                        obscure: !_passwordVisible,
                        textInputAction: TextInputAction.done,
                        errorText: _passwordError,
                        onSubmitted: (_) => _login(),
                        onChanged: (_) {
                          if (_passwordError != null) {
                            setState(() => _passwordError = null);
                          }
                        },
                        trailing: IconButton(
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: 18,
                            color: AppColors.fgTertiary,
                          ),
                          onPressed: () => setState(
                            () => _passwordVisible = !_passwordVisible,
                          ),
                          splashRadius: 18,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Primary CTA — lime, lg (56h), full width.
                      AppButton(
                        label: 'Comenzar turno',
                        trailingIcon: Icons.play_arrow_rounded,
                        variant: AppButtonVariant.primary,
                        size: AppButtonSize.lg,
                        fullWidth: true,
                        isLoading: authState.isLoading,
                        onPressed: _login,
                      ),

                      const SizedBox(height: 16),

                      // Footer help text — discreet but reachable.
                      Center(
                        child: Text.rich(
                          TextSpan(
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.fgTertiary,
                              fontSize: 12,
                            ),
                            children: const [
                              TextSpan(text: '¿Problemas? Contactá a '),
                              TextSpan(
                                text: 'tu coordinador',
                                style: TextStyle(
                                  color: AppColors.fgSecondary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Error banner (kept similar to the previous screen for parity)
// ─────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: AppRadius.rMd,
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.fgPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Logo mark — two chevrons (lime + white). Same as splash but smaller.
// ─────────────────────────────────────────────────────────────────────

class _LogoMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 4;

    final top = Path()
      ..moveTo(w * 0.15, h * 0.4)
      ..lineTo(w * 0.5, h * 0.1)
      ..lineTo(w * 0.85, h * 0.4);
    final bottom = Path()
      ..moveTo(w * 0.15, h * 0.85)
      ..lineTo(w * 0.5, h * 0.55)
      ..lineTo(w * 0.85, h * 0.85);

    stroke.color = AppColors.lime;
    canvas.drawPath(top, stroke);
    stroke.color = AppColors.fgPrimary;
    canvas.drawPath(bottom, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────
// Login key art — grid + radial lime glow + sample route + vignette.
//
// The sample route lives in the upper-half of the screen so the form
// area (lower half) is darker and more legible. Stop dots are mostly
// white, with the start + destination in lime to bookend the journey.
// ─────────────────────────────────────────────────────────────────────

class _LoginKeyArtPainter extends CustomPainter {
  const _LoginKeyArtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Solid base (slightly darker than bgBase so the glow stands out).
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0E1116),
    );

    // 2. Grid — 36×36 px, ~0.7 stroke, very dim.
    final gridPaint = Paint()
      ..color = const Color(0xFF1A2228)
      ..strokeWidth = 0.7;
    const step = 36.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 3. Radial lime glow — anchored in the upper third where the route
    //    lives. We use a fraction of the height so it scales to any
    //    device.
    final glowCenter = Offset(size.width * 0.5, size.height * 0.35);
    final glowRadius = size.width * 0.65;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.lime.withValues(alpha: 0.35),
          AppColors.lime.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: glowCenter, radius: glowRadius),
      )
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(glowCenter, glowRadius, glow);

    // 4. Sample route — 7 points roughly mirroring the design's
    //    `D3Login` polyline. Coordinates are normalised to the design's
    //    380×800 viewBox and scaled to fit the canvas.
    const designW = 380.0;
    const designH = 800.0;
    final sx = size.width / designW;
    final sy = size.height / designH;
    final route = <Offset>[
      Offset(60 * sx, 560 * sy),
      Offset(110 * sx, 500 * sy),
      Offset(200 * sx, 470 * sy),
      Offset(280 * sx, 380 * sy),
      Offset(230 * sx, 300 * sy),
      Offset(130 * sx, 220 * sy),
      Offset(60 * sx, 160 * sy),
    ];

    final routePath = Path()..moveTo(route.first.dx, route.first.dy);
    for (var i = 1; i < route.length; i++) {
      routePath.lineTo(route[i].dx, route[i].dy);
    }

    // Halo behind the route — wide, very low opacity, so the lime
    // "bleeds" into the background.
    final halo = Paint()
      ..color = AppColors.lime.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(routePath, halo);

    // Main route stroke.
    final routeStroke = Paint()
      ..color = AppColors.lime
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(routePath, routeStroke);

    // Dots — first lime, middle 5 white, last larger white-with-border.
    for (var i = 0; i < route.length; i++) {
      final isStart = i == 0;
      final isEnd = i == route.length - 1;
      final color = isStart ? AppColors.lime : AppColors.fgPrimary;
      final radius = isEnd ? 9.0 : (isStart ? 7.0 : 5.0);

      if (isEnd) {
        canvas.drawCircle(
          route[i],
          radius + 2,
          Paint()..color = const Color(0xFF0E1116),
        );
      }
      canvas.drawCircle(route[i], radius, Paint()..color = color);
    }

    // 5. Vertical vignette — transparent at top, opaque at the bottom
    //    so the form area is legible. The middle stop fades in around
    //    50%, matching the design exactly.
    final vignette = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x000F1220),
          Color(0x800F1220),
          Color(0xF20F1220),
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
