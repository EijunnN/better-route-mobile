import 'package:flutter/material.dart';

/// Corner radius scale. Sheets and full surfaces use [xl], cards [lg],
/// buttons and pills [md]/[full]. Avoid mixing more than two radii on the
/// same surface.
abstract class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double full = 999;

  static BorderRadius get rXs => BorderRadius.circular(xs);
  static BorderRadius get rSm => BorderRadius.circular(sm);
  static BorderRadius get rMd => BorderRadius.circular(md);
  static BorderRadius get rLg => BorderRadius.circular(lg);
  static BorderRadius get rXl => BorderRadius.circular(xl);
  static BorderRadius get rXxl => BorderRadius.circular(xxl);
  static BorderRadius get rFull => BorderRadius.circular(full);

  static const BorderRadius topXl = BorderRadius.only(
    topLeft: Radius.circular(xl),
    topRight: Radius.circular(xl),
  );
}
