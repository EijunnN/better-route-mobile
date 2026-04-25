import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Typographic scale for Driver Cockpit.
///
/// Two families:
///  - **Inter Tight** for human content (labels, body, headlines). Picked
///    over plain Inter for tighter letterforms at large sizes — gives
///    headlines more presence without a separate display font.
///  - **JetBrains Mono** for tabular data (timestamps, IDs, distances,
///    coordinates, plate numbers). Anything that benefits from monospace
///    alignment in lists.
///
/// The system rejects shadcn_flutter's default text styles entirely.
abstract class AppTypography {
  static TextStyle _sans({
    required double size,
    required FontWeight weight,
    double? height,
    double? letterSpacing,
    Color? color,
  }) {
    return GoogleFonts.interTight(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color ?? AppColors.fgPrimary,
    );
  }

  static TextStyle _mono({
    required double size,
    required FontWeight weight,
    double? letterSpacing,
    Color? color,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color ?? AppColors.fgPrimary,
    );
  }

  // Display / page titles.
  static TextStyle get display => _sans(
        size: 40,
        weight: FontWeight.w700,
        height: 1.05,
        letterSpacing: -0.8,
      );

  static TextStyle get h1 => _sans(
        size: 32,
        weight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -0.6,
      );

  static TextStyle get h2 => _sans(
        size: 24,
        weight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.3,
      );

  static TextStyle get h3 => _sans(
        size: 20,
        weight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -0.2,
      );

  static TextStyle get h4 => _sans(
        size: 17,
        weight: FontWeight.w600,
        height: 1.3,
      );

  // Body.
  static TextStyle get body => _sans(
        size: 15,
        weight: FontWeight.w400,
        height: 1.45,
      );

  static TextStyle get bodyMedium => _sans(
        size: 15,
        weight: FontWeight.w500,
        height: 1.45,
      );

  static TextStyle get bodySmall => _sans(
        size: 13,
        weight: FontWeight.w400,
        height: 1.4,
        color: AppColors.fgSecondary,
      );

  // UI primitives.
  static TextStyle get label => _sans(
        size: 13,
        weight: FontWeight.w600,
        letterSpacing: 0.1,
      );

  static TextStyle get labelSmall => _sans(
        size: 11,
        weight: FontWeight.w600,
        letterSpacing: 0.4,
        color: AppColors.fgSecondary,
      );

  /// Eyebrow / overline. ALL CAPS, used sparingly.
  static TextStyle get overline => _sans(
        size: 11,
        weight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppColors.fgTertiary,
      );

  // CTAs.
  static TextStyle get button => _sans(
        size: 15,
        weight: FontWeight.w600,
        letterSpacing: -0.1,
      );

  static TextStyle get buttonLarge => _sans(
        size: 17,
        weight: FontWeight.w600,
        letterSpacing: -0.1,
      );

  // Monospace — data.
  /// Big stat numbers (KPI blocks, timers).
  static TextStyle get statLarge => _mono(
        size: 32,
        weight: FontWeight.w600,
        letterSpacing: -1,
      );

  static TextStyle get statMedium => _mono(
        size: 22,
        weight: FontWeight.w600,
        letterSpacing: -0.5,
      );

  static TextStyle get mono => _mono(
        size: 13,
        weight: FontWeight.w500,
        letterSpacing: 0,
        color: AppColors.fgSecondary,
      );

  static TextStyle get monoSmall => _mono(
        size: 11,
        weight: FontWeight.w500,
        color: AppColors.fgTertiary,
      );
}
