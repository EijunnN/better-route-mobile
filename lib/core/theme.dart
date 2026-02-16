import 'package:shadcn_flutter/shadcn_flutter.dart';

/// App Theme Configuration using shadcn_flutter ColorScheme
/// Colors match the web frontend (globals.css) golden/amber palette
class AppTheme {
  static ColorScheme get lightScheme {
    return const ColorScheme(
      brightness: Brightness.light,
      background: Color(0xFFFFFFFF),
      foreground: Color(0xFF2D3254),
      card: Color(0xFFFFFFFF),
      cardForeground: Color(0xFF2D3254),
      popover: Color(0xFFFFFFFF),
      popoverForeground: Color(0xFF2D3254),
      primary: Color(0xFFC49A2D),
      primaryForeground: Color(0xFFFFFFFF),
      secondary: Color(0xFF507F8A),
      secondaryForeground: Color(0xFFFFFFFF),
      muted: Color(0xFFF5F4F8),
      mutedForeground: Color(0xFF6E7094),
      accent: Color(0xFFF0F0F0),
      accentForeground: Color(0xFF2D3254),
      destructive: Color(0xFFDC4840),
      border: Color(0xFFE4E2EA),
      input: Color(0xFFE4E2EA),
      ring: Color(0xFFC49A2D),
      chart1: Color(0xFFC49A2D),
      chart2: Color(0xFF507F8A),
      chart3: Color(0xFF16A34A),
      chart4: Color(0xFFDC4840),
      chart5: Color(0xFF6E7094),
    );
  }

  static ColorScheme get darkScheme {
    return const ColorScheme(
      brightness: Brightness.dark,
      background: Color(0xFF1C1A2C),
      foreground: Color(0xFFCFCFCF),
      card: Color(0xFF2C2C2C),
      cardForeground: Color(0xFFCFCFCF),
      popover: Color(0xFF2C2C2C),
      popoverForeground: Color(0xFFCFCFCF),
      primary: Color(0xFFD4AA2A),
      primaryForeground: Color(0xFF1C1A2C),
      secondary: Color(0xFF5B8BC7),
      secondaryForeground: Color(0xFF1C1A2C),
      muted: Color(0xFF404050),
      mutedForeground: Color(0xFF9E9EAE),
      accent: Color(0xFF3A3A4A),
      accentForeground: Color(0xFFCFCFCF),
      destructive: Color(0xFFFF6467),
      border: Color(0xFF404050),
      input: Color(0xFF404050),
      ring: Color(0xFFD4AA2A),
      chart1: Color(0xFFD4AA2A),
      chart2: Color(0xFF5B8BC7),
      chart3: Color(0xFF4ADE80),
      chart4: Color(0xFFFF6467),
      chart5: Color(0xFF9E9EAE),
    );
  }

  static ThemeData get light {
    return ThemeData(
      colorScheme: lightScheme,
      radius: 0.75,
    );
  }

  static ThemeData get dark {
    return ThemeData(
      colorScheme: darkScheme,
      radius: 0.75,
    );
  }
}

/// Status colors for stop/delivery states
class StatusColors {
  static const Color pending = Color(0xFF6E7094);
  static const Color pendingBg = Color(0xFFF5F4F8);

  static const Color inProgress = Color(0xFFC49A2D);
  static const Color inProgressBg = Color(0xFFFFF8E6);

  static const Color completed = Color(0xFF16A34A);
  static const Color completedBg = Color(0xFFDCFCE7);

  static const Color failed = Color(0xFFDC4840);
  static const Color failedBg = Color(0xFFFEE2E2);

  static const Color skipped = Color(0xFF6B7280);
  static const Color skippedBg = Color(0xFFF3F4F6);
}
