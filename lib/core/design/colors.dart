import 'package:flutter/material.dart';

/// Driver Cockpit color tokens.
///
/// Dark-first palette tuned for outdoor use (high contrast under sunlight).
/// Inspired by professional driver apps (Uber Driver, Tesla Mobile) but with
/// a sharper accent system: white for primary CTAs (clean, recognizable) and
/// a jade accent for "live/active" semantics (in motion, completed,
/// confirmation). Status colors deliberately reuse the same jade for
/// completion to reinforce the "good outcome = green" pattern.
abstract class AppColors {
  // Background layers — NOT pure black; pure black hides the surface
  // hierarchy because nothing can sit "below" it. We use a slightly
  // off-black base so elevated surfaces have somewhere to lift toward.
  static const Color bgBase = Color(0xFF0A0A0B);
  static const Color bgSurface = Color(0xFF161618);
  static const Color bgSurfaceElevated = Color(0xFF1F1F22);
  static const Color bgSurfaceHover = Color(0xFF26262A);
  static const Color bgOverlay = Color(0xCC000000); // 80% black for sheet backdrop

  // Borders — calibrated to be visible but never compete with content.
  static const Color borderSubtle = Color(0xFF2A2A2E);
  static const Color borderStrong = Color(0xFF3A3A3F);
  static const Color borderFocus = Color(0xFFFFFFFF);

  // Foreground — three tiers of emphasis.
  static const Color fgPrimary = Color(0xFFFAFAFA);
  static const Color fgSecondary = Color(0xFFA1A1AA);
  static const Color fgTertiary = Color(0xFF71717A);
  static const Color fgDisabled = Color(0xFF52525B);
  static const Color fgInverse = Color(0xFF0A0A0B); // Text on white CTA

  // Accents — used with extreme economy. Each color earns its place.
  static const Color accentPrimary = Color(0xFFFFFFFF);
  static const Color accentLive = Color(0xFF22D3A2); // Jade — active/in motion
  static const Color accentLiveDim = Color(0xFF14855F); // For backgrounds
  static const Color accentWarning = Color(0xFFFFB020);
  static const Color accentWarningDim = Color(0xFF7A5210);
  static const Color accentDanger = Color(0xFFFF5757);
  static const Color accentDangerDim = Color(0xFF7F2929);
  static const Color accentInfo = Color(0xFF60A5FA);

  // Status — tied to delivery lifecycle.
  static const Color statusPending = fgTertiary;
  static const Color statusPendingBg = Color(0xFF26262A);
  static const Color statusInProgress = accentLive;
  static const Color statusInProgressBg = Color(0xFF0F2922);
  static const Color statusCompleted = accentLive;
  static const Color statusCompletedBg = Color(0xFF0F2922);
  static const Color statusFailed = accentDanger;
  static const Color statusFailedBg = Color(0xFF2A1212);
  static const Color statusSkipped = fgTertiary;
  static const Color statusSkippedBg = Color(0xFF26262A);
}
