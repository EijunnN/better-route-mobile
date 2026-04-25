import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'design/tokens.dart';

/// Driver Cockpit theme.
///
/// The app is dark-only by design — driver use case (outdoor, in motion,
/// long shifts) is best served by a high-contrast dark canvas with bright
/// content. We still expose [light] and [dark] for compatibility with
/// any leftover shadcn widgets, but both reuse the same dark palette.
///
/// Custom screens should rely on [AppColors]/[AppTypography] directly,
/// NOT on Theme.of(context).colorScheme — the design system is decoupled
/// from shadcn's theming so we can swap it out later without bleeding
/// changes through every screen.
class AppTheme {
  static ColorScheme get _scheme => const ColorScheme(
        brightness: Brightness.dark,
        background: AppColors.bgBase,
        foreground: AppColors.fgPrimary,
        card: AppColors.bgSurface,
        cardForeground: AppColors.fgPrimary,
        popover: AppColors.bgSurfaceElevated,
        popoverForeground: AppColors.fgPrimary,
        primary: AppColors.accentPrimary,
        primaryForeground: AppColors.fgInverse,
        secondary: AppColors.bgSurfaceElevated,
        secondaryForeground: AppColors.fgPrimary,
        muted: AppColors.bgSurface,
        mutedForeground: AppColors.fgSecondary,
        accent: AppColors.accentLive,
        accentForeground: AppColors.fgInverse,
        destructive: AppColors.accentDanger,
        border: AppColors.borderSubtle,
        input: AppColors.borderSubtle,
        ring: AppColors.accentPrimary,
        chart1: AppColors.accentLive,
        chart2: AppColors.accentInfo,
        chart3: AppColors.accentWarning,
        chart4: AppColors.accentDanger,
        chart5: AppColors.fgSecondary,
      );

  static ThemeData get light =>
      ThemeData(colorScheme: _scheme, radius: AppRadius.md / 16);
  static ThemeData get dark =>
      ThemeData(colorScheme: _scheme, radius: AppRadius.md / 16);
}

/// Legacy status color helpers kept around so widgets that haven't been
/// migrated yet (notes card backgrounds, etc.) continue to compile while
/// the redesign rolls out screen by screen.
class StatusColors {
  static const pending = AppColors.statusPending;
  static const inProgress = AppColors.statusInProgress;
  static const completed = AppColors.statusCompleted;
  static const failed = AppColors.statusFailed;
  static const skipped = AppColors.statusSkipped;

  // The "Background(brightness)" overloads originally returned different
  // colors for light/dark. Driver Cockpit is dark-only, so these now
  // collapse to a single value.
  static dynamic pendingBackground(_) => AppColors.statusPendingBg;
  static dynamic inProgressBackground(_) => AppColors.statusInProgressBg;
  static dynamic completedBackground(_) => AppColors.statusCompletedBg;
  static dynamic failedBackground(_) => AppColors.statusFailedBg;
  static dynamic skippedBackground(_) => AppColors.statusSkippedBg;

  static const notesBg = AppColors.bgSurfaceElevated;
  static const notesAccent = AppColors.accentWarning;
  static dynamic notesBackground(_) => notesBg;
  static dynamic notesAccentColor(_) => notesAccent;
}
