import 'package:flutter/material.dart';

/// Animation durations and curves. Three speeds + a single curve family
/// (`emphasized`) so the app feels coherent — every transition uses the
/// same easing language, only the duration changes by surface size.
abstract class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 350);
  static const Duration deliberate = Duration(milliseconds: 500);

  /// Material 3 emphasized — "decisive" feel for entries/exits.
  static const Curve emphasized = Cubic(0.2, 0, 0, 1);

  /// For hover/press — quick, no overshoot.
  static const Curve standardCurve = Curves.easeOutCubic;

  /// For sheets that should feel weighted (drag back, settle).
  static const Curve sheet = Cubic(0.32, 0.72, 0, 1);
}
