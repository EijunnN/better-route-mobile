import 'package:flutter/material.dart';

/// Driver Cockpit color tokens.
///
/// Dark-only palette, aligned 1:1 with the BetterRoute web admin
/// (`planeamiento/src/app/globals.css` → `.dark`). Lime primary on
/// dark-navy backgrounds. Specs in `Mobile - Specs.html` § 02.
///
/// **Migration note.** Pre-redesign the accent was jade `#4AB855` on
/// off-black `#0A0A0B`. This file now ships the lime/navy palette but
/// keeps the legacy field NAMES (`accentLive`, `accentPrimary`, etc.)
/// pointing at the new values, so dozens of consumers compile without
/// touching them. New code can use the semantic aliases at the bottom
/// (`lime`, `limeSoft`, `bgElevated`) for clarity.
abstract class AppColors {
  // ─────────────────────────────────────────────────────────────────
  // Backgrounds — dark-navy stack, three elevation tiers.
  // ─────────────────────────────────────────────────────────────────

  /// Scaffold body. oklch(0.1288 0.0406 264.69).
  static const Color bgBase = Color(0xFF0F1220);

  /// Cards, list rows. oklch(0.2077 0.0398 265.75).
  static const Color bgSurface = Color(0xFF1A1D2E);

  /// Sheets, inputs, modals. oklch(0.2495 0.0368 260.03).
  static const Color bgSurfaceElevated = Color(0xFF232639);

  /// Hover state for tappable rows.
  static const Color bgSurfaceHover = Color(0xFF2C2F44);

  /// 72% black scrim used under sheets and dialogs.
  static const Color bgOverlay = Color(0xB8000000);

  // ─────────────────────────────────────────────────────────────────
  // Borders
  // ─────────────────────────────────────────────────────────────────

  /// Hairline between rows / inside cards. oklch(0.2795 0.0368 260.03).
  static const Color borderSubtle = Color(0xFF2C2F44);

  /// Outlined buttons, focus rings on inputs. oklch(0.35 0.04 260).
  static const Color borderStrong = Color(0xFF3A3D54);

  /// Lime, only when an input is focused.
  static const Color borderFocus = lime;

  // ─────────────────────────────────────────────────────────────────
  // Foreground — three emphasis tiers + an inverse for use on lime.
  // ─────────────────────────────────────────────────────────────────

  /// Body text, primary content. oklch(0.9842 0.0034 247.85).
  static const Color fgPrimary = Color(0xFFE8EAEF);

  /// Subtitles, secondary body. oklch(0.7107 0.0351 256.79).
  static const Color fgSecondary = Color(0xFF9EA1B3);

  /// Captions, placeholders, footnotes. oklch(0.5544 0.0407 257.42).
  static const Color fgTertiary = Color(0xFF6C6F82);

  /// Disabled controls.
  static const Color fgDisabled = Color(0xFF52525B);

  /// Text on lime — always pure black per QA checklist
  /// ("never white on lime — always black on lime").
  static const Color fgInverse = Color(0xFF000000);

  // ─────────────────────────────────────────────────────────────────
  // Accents — lime primary, with semantic warning/danger/info.
  // ─────────────────────────────────────────────────────────────────

  /// Brand lime. CTAs, current marker, active state, "live", success.
  /// oklch(0.8871 0.2122 128.50).
  static const Color lime = Color(0xFFC5F33A);

  /// Lime at 16% alpha. Selected backgrounds, active badges.
  static const Color limeSoft = Color(0x29C5F33A);

  /// Darker lime — only for placeholder backgrounds, never text.
  /// oklch(0.3925 0.0896 152.53).
  static const Color limeDim = Color(0xFF3F6624);

  /// Amber. Dispatch notes, "atención" callouts.
  /// oklch(0.85 0.13 80).
  static const Color warning = Color(0xFFFFB020);

  /// Amber at 16% alpha.
  static const Color warningSoft = Color(0x29FFB020);

  /// Amber dim (border, hover).
  static const Color warningDim = Color(0xFF7A5210);

  /// Coral. "No entregó", validation errors, destructive actions.
  /// oklch(0.7 0.2078 25.33).
  static const Color danger = Color(0xFFFF5757);

  /// Coral at 16% alpha.
  static const Color dangerSoft = Color(0x29FF5757);

  /// Coral dim.
  static const Color dangerDim = Color(0xFF7F2929);

  /// Info blue. Driver's own location marker on map. oklch(0.75 0.12 250).
  static const Color info = Color(0xFF60A5FA);

  /// Info at 24% alpha.
  static const Color infoSoft = Color(0x3D60A5FA);

  // ─────────────────────────────────────────────────────────────────
  // Legacy aliases — kept so existing widgets compile while the
  // redesign rolls out. Internally these now point at the lime tokens.
  // ─────────────────────────────────────────────────────────────────

  /// Was white; now lime. Used by primary CTAs across the app.
  static const Color accentPrimary = lime;
  static const Color accentLive = lime;
  static const Color accentLiveDim = limeDim;
  static const Color accentLiveSoft = limeSoft;
  static const Color accentWarning = warning;
  static const Color accentWarningDim = warningDim;
  static const Color accentDanger = danger;
  static const Color accentDangerDim = dangerDim;
  static const Color accentInfo = info;

  // ─────────────────────────────────────────────────────────────────
  // Status — delivery lifecycle. Same colours as before but on the
  // navy stack now, so backgrounds got recalibrated.
  // ─────────────────────────────────────────────────────────────────

  static const Color statusPending = fgTertiary;
  static const Color statusPendingBg = bgSurfaceElevated;
  static const Color statusInProgress = lime;
  static const Color statusInProgressBg = Color(0xFF1F2A1B);
  static const Color statusCompleted = lime;
  static const Color statusCompletedBg = Color(0xFF1F2A1B);
  static const Color statusFailed = danger;
  static const Color statusFailedBg = Color(0xFF2A1212);
}
