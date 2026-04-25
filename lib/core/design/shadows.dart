import 'package:flutter/material.dart';

/// Shadows for the dark theme. We don't use shadows the way light themes
/// do (lifting elements off white). Here they're used for inner-glow
/// accents on live elements (a thin colored glow under a status pill) and
/// for sheet backdrop scrim.
abstract class AppShadows {
  /// Subtle glow under live/active status pills.
  static const liveGlow = [
    BoxShadow(
      color: Color(0x4022D3A2),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  /// Sheet shadow — used to lift bottom sheets off the dark backdrop.
  static const sheet = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 32,
      offset: Offset(0, -8),
    ),
  ];

  /// Floating action card.
  static const elevated = [
    BoxShadow(
      color: Color(0x55000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}
